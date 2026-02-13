import AppKit
import SwiftUI

// MARK: - Overlay Window Manager

/// Manages transparent, click-through overlay windows on all connected displays.
/// Each window hosts a `GlowBorderView` that renders the animated Apple-icon glow.
final class OverlayWindowManager: ObservableObject {

    private var overlayWindows: [NSScreen: NSWindow] = [:]
    private var glowStates: [NSScreen: GlowBorderState] = [:]
    private let iconSize = NSSize(width: 22, height: 22)
    private let iconLeftPadding: CGFloat = 16
    private let iconVerticalOffset: CGFloat = -3

    /// Tracks currently active glow layers by internal glow key.
    @Published var activeGlows: [String: GlowLayer] = [:]

    init() {
        setupOverlays()
        observeScreenChanges()
    }

    // MARK: - Setup

    private func setupOverlays() {
        for screen in NSScreen.screens {
            createOverlayWindow(for: screen)
        }
    }

    private func createOverlayWindow(for screen: NSScreen) {
        let state = GlowBorderState()
        let glowView = GlowBorderView(state: state)
        let iconFrame = makeIconFrame(for: screen)

        let window = NSWindow(
            contentRect: iconFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Keep this above the system menu bar icon so the color fill replaces it visually.
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.contentView = NSHostingView(rootView: glowView)
        window.setFrame(iconFrame, display: true)
        window.orderFrontRegardless()

        overlayWindows[screen] = window
        glowStates[screen] = state
    }

    // MARK: - Screen Change Observation

    private func observeScreenChanges() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func screensDidChange() {
        // Tear down existing windows
        for (_, window) in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
        glowStates.removeAll()

        // Recreate for current screen configuration
        setupOverlays()

        // Re-apply active glows
        updateAllScreenGlows()
    }

    // MARK: - Glow Control

    /// Triggers a glow animation for a specific app notification.
    func triggerGlow(color: NSColor, notificationId: Int64, bundleIdentifier: String) {
        let glowKey = notificationGlowKey(for: notificationId)
        let layer = GlowLayer(
            color: color,
            bundleIdentifier: bundleIdentifier,
            startTime: Date()
        )

        activeGlows[glowKey] = layer
        updateAllScreenGlows()
    }

    /// Dismisses the glow for a specific notification.
    func dismissGlow(notificationId: Int64) {
        let glowKey = notificationGlowKey(for: notificationId)
        dismissGlow(forKey: glowKey)
    }

    private func dismissGlow(forKey glowKey: String) {
        activeGlows.removeValue(forKey: glowKey)
        updateAllScreenGlows()
    }

    /// Dismisses all active glows.
    func dismissAllGlows() {
        activeGlows.removeAll()
        updateAllScreenGlows()
    }

    /// Triggers a test glow animation.
    func triggerTestGlow() {
        let testColors: [NSColor] = [
            NSColor(red: 0.42, green: 0.35, blue: 0.95, alpha: 1.0),
            NSColor(red: 0.95, green: 0.30, blue: 0.45, alpha: 1.0),
            NSColor(red: 0.20, green: 0.85, blue: 0.65, alpha: 1.0),
        ]

        for (index, color) in testColors.enumerated() {
            let glowKey = "test-\(index)"
            let layer = GlowLayer(
                color: color,
                bundleIdentifier: glowKey,
                startTime: Date()
            )
            activeGlows[glowKey] = layer
        }

        updateAllScreenGlows()

        // Auto-dismiss test glows after 6 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) { [weak self] in
            self?.activeGlows.removeValue(forKey: "test-0")
            self?.activeGlows.removeValue(forKey: "test-1")
            self?.activeGlows.removeValue(forKey: "test-2")
            self?.updateAllScreenGlows()
        }
    }

    // MARK: - Internal

    private func makeIconFrame(for screen: NSScreen) -> NSRect {
        let menuBarHeight = NSStatusBar.system.thickness
        let centeredY = screen.frame.maxY - menuBarHeight + ((menuBarHeight - iconSize.height) / 2.0)

        return NSRect(
            x: screen.frame.minX + iconLeftPadding,
            y: centeredY + iconVerticalOffset,
            width: iconSize.width,
            height: iconSize.height
        )
    }

    private func updateAllScreenGlows() {
        let colors = aggregatedActiveColors()
        for (_, state) in glowStates {
            state.updateColors(colors)
        }
    }

    /// Aggregates colors by notification type (bundle identifier).
    /// A type contributes one color while it still has unread notifications.
    private func aggregatedActiveColors() -> [NSColor] {
        let grouped = Dictionary(grouping: activeGlows.values, by: { $0.bundleIdentifier })

        let representatives = grouped.values.compactMap { layers in
            layers.min(by: { $0.startTime < $1.startTime })
        }

        return representatives
            .sorted(by: { $0.startTime < $1.startTime })
            .map(\.color)
    }

    private func notificationGlowKey(for notificationId: Int64) -> String {
        return "notification-\(notificationId)"
    }
}

// MARK: - Glow Layer Model

struct GlowLayer: Identifiable {
    let id = UUID()
    let color: NSColor
    let bundleIdentifier: String
    let startTime: Date
}
