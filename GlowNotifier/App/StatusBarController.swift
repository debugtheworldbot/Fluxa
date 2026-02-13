import AppKit
import SwiftUI

// MARK: - Status Bar Controller

/// Manages the menu bar icon and its associated popover/menu.
final class StatusBarController {

    private var statusItem: NSStatusItem
    private var settingsWindow: NSWindow?

    private let appSettings: AppSettings
    private let overlayManager: OverlayWindowManager
    private let notificationEngine: NotificationEngine

    init(
        appSettings: AppSettings,
        overlayManager: OverlayWindowManager,
        notificationEngine: NotificationEngine
    ) {
        self.appSettings = appSettings
        self.overlayManager = overlayManager
        self.notificationEngine = notificationEngine

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupStatusBarIcon()
        setupMenu()
    }

    // MARK: - Setup

    private func setupStatusBarIcon() {
        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "circle.hexagongrid.fill",
                accessibilityDescription: "GlowNotifier"
            )
            image?.isTemplate = true
            button.image = image
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status header
        let statusItem = NSMenuItem(title: "GlowNotifier", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Test Animation
        let testItem = NSMenuItem(
            title: "Test Animation",
            action: #selector(testAnimation),
            keyEquivalent: "t"
        )
        testItem.target = self
        menu.addItem(testItem)

        // Dismiss All
        let dismissItem = NSMenuItem(
            title: "Dismiss All Glows",
            action: #selector(dismissAllGlows),
            keyEquivalent: "d"
        )
        dismissItem.target = self
        menu.addItem(dismissItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit GlowNotifier",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    // MARK: - Actions

    @objc private func testAnimation() {
        overlayManager.triggerTestGlow()
    }

    @objc private func dismissAllGlows() {
        overlayManager.dismissAllGlows()
    }

    @objc private func openSettings() {
        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView(
            appSettings: appSettings,
            overlayManager: overlayManager,
            notificationEngine: notificationEngine
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "GlowNotifier Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 560, height: 420)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        settingsWindow = window
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
