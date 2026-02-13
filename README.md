# GlowNotifier

A macOS menu bar app that displays animated, breathing screen border glows when notifications arrive. Each app is assigned a unique color — when multiple notifications are active simultaneously, the flowing colored lines create a beautiful rainbow effect around your entire screen.

Inspired by the Apple Intelligence Siri activation glow on iPhone.

## Features

- **Screen-wide animated glow** — A breathing, flowing gradient border around your entire screen
- **Per-app color assignment** — Each monitored app gets its own unique color
- **Rainbow multi-notification effect** — Multiple active notifications blend into a flowing rainbow
- **Multi-display support** — Works across all connected displays and Spaces
- **Customizable animation** — Adjust glow width, rotation speed, pulse intensity, and duration
- **Non-intrusive** — Click-through overlay that never blocks your workflow
- **Menu bar app** — Lives quietly in your menu bar, no Dock icon

## Requirements

- **macOS 13.0 (Ventura)** or later
- **Full Disk Access** permission (to read the notification database)
- **Xcode 15+** (for building from source)

## How It Works

GlowNotifier monitors the macOS notification center SQLite database located at:

```
~/Library/Group Containers/group.com.apple.usernoted/db2/db
```

It uses a combination of **FSEvents** (for real-time file system change detection) and a **polling fallback** (to catch SQLite WAL changes that FSEvents may miss). When a new notification is detected, the app:

1. Parses the database to identify the source application's bundle identifier
2. Looks up the user-configured color for that app
3. Triggers the animated glow border on all connected displays
4. Automatically fades out after the configured duration

## Project Structure

```
GlowNotifier/
├── GlowNotifier.xcodeproj/     # Xcode project
├── GlowNotifier/
│   ├── App/
│   │   ├── GlowNotifierApp.swift           # App entry point and delegate
│   │   └── StatusBarController.swift       # Menu bar icon and menu
│   ├── Views/
│   │   ├── GlowBorderView.swift            # Core animation view (breathing glow)
│   │   ├── SettingsView.swift              # Settings panel (tabs: Apps, Animation, Status, General)
│   │   └── OnboardingView.swift            # First-run onboarding flow
│   ├── Models/
│   │   ├── AppSettings.swift               # Persisted user settings and app config
│   │   └── GlowBorderState.swift           # Observable animation state
│   ├── Services/
│   │   ├── OverlayWindowManager.swift      # Transparent overlay window management
│   │   ├── NotificationDatabaseMonitor.swift # FSEvents + polling database watcher
│   │   ├── NotificationDatabaseParser.swift  # SQLite database reader and parser
│   │   └── NotificationEngine.swift        # Core coordinator engine
│   ├── Assets.xcassets/                    # App icon and assets
│   ├── Info.plist                          # App configuration (LSUIElement, etc.)
│   └── GlowNotifier.entitlements           # Non-sandboxed entitlements
├── Scripts/
│   └── build_dmg.sh                        # Build, sign, notarize, and package script
├── Package.swift                           # SPM reference (primary build via Xcode)
├── .gitignore
└── README.md
```

## Building

### From Xcode

1. Open `GlowNotifier.xcodeproj` in Xcode
2. Select the `GlowNotifier` scheme
3. Build and Run (⌘R)

### Building a DMG for Distribution

```bash
# Set your signing credentials (optional, skip for unsigned builds)
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
export APPLE_ID="your@email.com"
export TEAM_ID="YOURTEAMID"
export APP_PASSWORD="your-app-specific-password"

# Build and package
./Scripts/build_dmg.sh
```

The script will:
1. Build a Release archive
2. Export the app
3. Notarize with Apple (if credentials are set)
4. Create a polished DMG installer

## Setup

1. **Launch GlowNotifier** — The onboarding flow will guide you through setup
2. **Grant Full Disk Access** — Required to read the notification database
   - The app will open the correct System Settings pane for you
   - Add GlowNotifier to the Full Disk Access list
3. **Configure your apps** — Open Settings from the menu bar to:
   - See which apps have sent notifications
   - Enable/disable monitoring per app
   - Customize the glow color for each app
   - Adjust animation parameters

## Architecture

```
┌─────────────────────────────────────────────────┐
│                  Full Disk Access                │
│                   (Permission)                   │
└──────────────────────┬──────────────────────────┘
                       │ grants access
┌──────────────────────▼──────────────────────────┐
│             Notification Source                   │
│  ┌─────────────────┐    ┌─────────────────────┐ │
│  │ FSEvents Monitor │───▶│   SQLite Parser     │ │
│  └─────────────────┘    └─────────┬───────────┘ │
└───────────────────────────────────┼─────────────┘
                                    │ bundle ID + timestamp
┌───────────────────────────────────▼─────────────┐
│              Core Logic Engine                    │
│  Identify App → Map to Color → Trigger Animation │
└───────────────────────────────────┬─────────────┘
                                    │
┌───────────────────────────────────▼─────────────┐
│               Visual Layer                        │
│  NSWindow Overlay → Core Animation → Glow Effect │
└─────────────────────────────────────────────────┘
```

## Customization

### Animation Parameters

| Parameter | Default | Range | Description |
|-----------|---------|-------|-------------|
| Glow Width | 4.0 pt | 1.0 - 12.0 | Width of the core glow line |
| Rotation Speed | 0.15 | 0.02 - 0.50 | Speed of gradient rotation (rev/s) |
| Pulse Intensity | 50% | 0% - 100% | Strength of the breathing pulse |
| Glow Duration | 8s | 2s - 30s | How long the glow persists |

### Default Color Palette

The app auto-assigns colors from a curated palette when new apps are discovered:

| Color | Hex | Preview |
|-------|-----|---------|
| Purple | `#7B61FF` | 🟣 |
| Coral Red | `#FF6B6B` | 🔴 |
| Teal | `#4ECDC4` | 🟢 |
| Yellow | `#FFE66D` | 🟡 |
| Orange | `#FF8A5C` | 🟠 |
| Pink | `#FF71CE` | 🩷 |
| Cyan | `#01CDFE` | 🔵 |

## Known Limitations

- **Requires Full Disk Access** — This is a macOS security requirement for reading the notification database. There is no way around this for non-sandboxed apps.
- **macOS version dependency** — The notification database path and schema may change between macOS versions. Currently tested on macOS Sequoia.
- **FSEvents latency** — SQLite WAL file changes may not always trigger FSEvents immediately. The 2-second polling fallback mitigates this.

## License

MIT License. See [LICENSE](LICENSE) for details.
