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
ARCHIVE_PATH="${BUILD_DIR}/${APP_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
APP_PATH="${EXPORT_PATH}/${APP_NAME}.app"
DMG_PATH="${BUILD_DIR}/${APP_NAME}.dmg"
VERSION=$(grep -A1 'MARKETING_VERSION' GlowNotifier.xcodeproj/project.pbxproj | head -1 | grep -o '[0-9.]*' | head -1)

echo "============================================"
echo "  Building ${APP_NAME} v${VERSION}"
echo "============================================"

# Step 1: Clean and build archive
echo ""
echo "[1/5] Building archive..."
xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="${DEVELOPER_ID:-}" \
    ENABLE_APP_SANDBOX=NO \
    | xcpretty || xcodebuild archive \
    -project "${APP_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="${DEVELOPER_ID:-}" \
    ENABLE_APP_SANDBOX=NO

# Step 2: Export the app from the archive
echo ""
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
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "${ARCHIVE_PATH}" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    -exportPath "${EXPORT_PATH}"

# Step 3: Notarize the app
echo ""
echo "[3/5] Notarizing..."

if [ -n "${APPLE_ID:-}" ] && [ -n "${TEAM_ID:-}" ] && [ -n "${APP_PASSWORD:-}" ]; then
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
    echo "  Skipping notarization (credentials not set)."
    echo "  Set APPLE_ID, TEAM_ID, and APP_PASSWORD to enable."
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
