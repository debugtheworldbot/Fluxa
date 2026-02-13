// swift-tools-version: 5.9
// This Package.swift is provided as a reference for dependencies.
// The primary build method is via the Xcode project (GlowNotifier.xcodeproj).

import PackageDescription

let package = Package(
    name: "GlowNotifier",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "GlowNotifier",
            path: "GlowNotifier",
            exclude: ["Assets.xcassets", "Info.plist", "GlowNotifier.entitlements"],
            linkerSettings: [
                .linkedLibrary("sqlite3")
            ]
        )
    ]
)
