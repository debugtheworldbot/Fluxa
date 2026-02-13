#!/bin/bash
# =============================================================================
# GlowNotifier - Build, Sign, Notarize, and Package as DMG
# =============================================================================
#
# Prerequisites:
#   1. Xcode installed with command line tools
#   2. Apple Developer ID certificate in Keychain
#   3. App-specific password stored in Keychain for notarization
#   4. `create-dmg` installed: brew install create-dmg
#
# Usage:
#   ./Scripts/build_dmg.sh
#
# Environment Variables (set these before running):
#   DEVELOPER_ID    - Your Developer ID Application certificate name
#                     e.g., "Developer ID Application: Your Name (TEAMID)"
#   APPLE_ID        - Your Apple ID email for notarization
#   TEAM_ID         - Your Apple Developer Team ID
#   APP_PASSWORD    - App-specific password (or keychain profile name)
# =============================================================================

set -euo pipefail

# Configuration
APP_NAME="GlowNotifier"
SCHEME="GlowNotifier"
BUILD_DIR="./build"
DERIVED_DATA_PATH="${BUILD_DIR}/DerivedData"
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH=""
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
VERSION=$(grep -A1 'MARKETING_VERSION' GlowNotifier.xcodeproj/project.pbxproj | head -1 | grep -o '[0-9.]*' | head -1)

# Resolve signing configuration from project first, then keychain.
PROJECT_BUILD_SETTINGS=$(
    xcodebuild -project "${APP_NAME}.xcodeproj" \
        -scheme "${SCHEME}" \
        -configuration Release \
        -showBuildSettings 2>/dev/null || true
)
PROJECT_DEVELOPER_ID_RAW=$(echo "${PROJECT_BUILD_SETTINGS}" | awk -F' = ' '/^[[:space:]]*CODE_SIGN_IDENTITY = / { print $2; exit }')
PROJECT_TEAM_ID=$(echo "${PROJECT_BUILD_SETTINGS}" | awk -F' = ' '/^[[:space:]]*DEVELOPMENT_TEAM = / { print $2; exit }')

# Xcode automatic signing often reports "-" (Sign to Run Locally), which is not
# valid for Developer ID export. Only accept an explicit Developer ID identity.
PROJECT_DEVELOPER_ID=""
if [[ "${PROJECT_DEVELOPER_ID_RAW:-}" == Developer\ ID\ Application:* ]]; then
    PROJECT_DEVELOPER_ID="${PROJECT_DEVELOPER_ID_RAW}"
fi

KEYCHAIN_DEVELOPER_ID=$(security find-identity -v -p codesigning 2>/dev/null \
    | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' \
    | head -n 1)

DEVELOPER_ID="${DEVELOPER_ID:-${PROJECT_DEVELOPER_ID:-${KEYCHAIN_DEVELOPER_ID:-}}}"
TEAM_ID="${TEAM_ID:-${PROJECT_TEAM_ID:-}}"

# Infer Team ID from Developer ID identity if project doesn't expose DEVELOPMENT_TEAM.
# Example: Developer ID Application: Name (ABCDE12345)
if [ -z "${TEAM_ID}" ] && [ -n "${DEVELOPER_ID}" ]; then
    TEAM_ID_FROM_IDENTITY=$(echo "${DEVELOPER_ID}" | sed -n 's/.*(\([A-Z0-9]\{10\}\)).*/\1/p')
    TEAM_ID="${TEAM_ID_FROM_IDENTITY:-}"
fi

SIGNING_MODE="local"
if [ -n "${DEVELOPER_ID}" ] && [ -n "${TEAM_ID}" ]; then
    SIGNING_MODE="developer-id"
fi

echo "============================================"
echo "  Building ${APP_NAME} v${VERSION}"
echo "============================================"
echo "  Mode: ${SIGNING_MODE}"
echo "  Signing identity: ${DEVELOPER_ID:-<auto>}"
echo "  Team ID: ${TEAM_ID:-<auto>}"

# Step 1: Clean and build archive
echo ""
echo "[1/5] Building archive..."
ARCHIVE_CMD=(
    xcodebuild archive
    -project "${APP_NAME}.xcodeproj"
    -scheme "${SCHEME}"
    -configuration Release
    -derivedDataPath "${DERIVED_DATA_PATH}"
    -archivePath "${ARCHIVE_PATH}"
    ENABLE_APP_SANDBOX=NO
)
if [ "${SIGNING_MODE}" = "developer-id" ] && [ -n "${DEVELOPER_ID}" ]; then
    ARCHIVE_CMD+=("CODE_SIGN_IDENTITY=${DEVELOPER_ID}")
fi
if [ "${SIGNING_MODE}" = "developer-id" ] && [ -n "${TEAM_ID}" ]; then
    ARCHIVE_CMD+=("DEVELOPMENT_TEAM=${TEAM_ID}")
fi
if [ "${SIGNING_MODE}" = "local" ]; then
    ARCHIVE_CMD+=("CODE_SIGN_IDENTITY=-")
fi

if command -v xcpretty >/dev/null 2>&1; then
    "${ARCHIVE_CMD[@]}" | xcpretty
else
    "${ARCHIVE_CMD[@]}"
fi

# Step 2: Export the app from the archive
echo ""
if [ "${SIGNING_MODE}" = "developer-id" ]; then
    echo "[2/5] Exporting app..."
    cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>signingStyle</key>
    <string>automatic</string>
$(if [ -n "${TEAM_ID}" ]; then
    cat <<TEAMEOF
    <key>teamID</key>
    <string>${TEAM_ID}</string>
TEAMEOF
fi)
</dict>
</plist>
EOF

    xcodebuild -exportArchive \
        -archivePath "${ARCHIVE_PATH}" \
        -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
        -exportPath "${EXPORT_PATH}"

    APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
else
    echo "[2/5] Using archived app (Sign to Run Locally mode)..."
    APP_PATH="${ARCHIVE_PATH}/Products/Applications/${APP_NAME}.app"
fi

if [ ! -d "${APP_PATH}" ]; then
    echo "error: App bundle not found at ${APP_PATH}"
    exit 1
fi

# Step 3: Notarize the app
echo ""
echo "[3/5] Notarizing..."

if [ "${SIGNING_MODE}" = "developer-id" ] && [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
    # Create a zip for notarization
    ditto -c -k --keepParent "${APP_PATH}" "${BUILD_DIR}/${APP_NAME}.zip"

    xcrun notarytool submit "${BUILD_DIR}/${APP_NAME}.zip" \
        --apple-id "${APPLE_ID}" \
        --team-id "${TEAM_ID}" \
        --password "${APP_PASSWORD}" \
        --wait

    # Staple the notarization ticket
    xcrun stapler staple "${APP_PATH}"

    echo "  Notarization complete and stapled."
    rm -f "${BUILD_DIR}/${APP_NAME}.zip"
else
    if [ "${SIGNING_MODE}" = "local" ]; then
        echo "  Skipping notarization (local signing mode)."
    else
        echo "  Skipping notarization (credentials not set)."
        echo "  Set APPLE_ID, TEAM_ID, and APP_PASSWORD to enable."
    fi
fi

# Step 4: Create DMG
echo ""
echo "[4/5] Creating DMG..."

# Remove old DMG if exists
rm -f "${DMG_PATH}"

if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "${APP_NAME}" \
        --volicon "${APP_PATH}/Contents/Resources/AppIcon.icns" \
        --window-pos 200 120 \
        --window-size 600 400 \
        --icon-size 100 \
        --icon "${APP_NAME}.app" 175 190 \
        --hide-extension "${APP_NAME}.app" \
        --app-drop-link 425 190 \
        --no-internet-enable \
        "${DMG_PATH}" \
        "${APP_PATH}" \
        || true  # create-dmg returns non-zero even on success sometimes
else
    echo "  create-dmg not found, using hdiutil fallback..."
    mkdir -p "${BUILD_DIR}/dmg_staging"
    cp -R "${APP_PATH}" "${BUILD_DIR}/dmg_staging/"
    ln -sf /Applications "${BUILD_DIR}/dmg_staging/Applications"
    hdiutil create -volname "${APP_NAME}" \
        -srcfolder "${BUILD_DIR}/dmg_staging" \
        -ov -format UDZO \
        "${DMG_PATH}"
    rm -rf "${BUILD_DIR}/dmg_staging"
fi

# Step 5: Summary
echo ""
echo "[5/5] Done!"
echo "============================================"
echo "  App:  ${APP_PATH}"
echo "  DMG:  ${DMG_PATH}"
echo "  Size: $(du -sh "${DMG_PATH}" | cut -f1)"
echo "============================================"
