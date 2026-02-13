import AppKit
import SwiftUI

// MARK: - Overlay Window Manager

/// Manages transparent, click-through overlay windows on all connected displays.
/// Each window hosts a `GlowBorderView` that renders the animated screen-edge glow.
final class OverlayWindowManager: ObservableObject {

    private var overlayWindows: [NSScreen: NSWindow] = [:]
    private var glowStates: [NSScreen: GlowBorderState] = [:]

    /// Tracks currently active glow layers by bundle identifier.
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

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.hasShadow = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        window.contentView = NSHostingView(rootView: glowView)
        window.setFrame(screen.frame, display: true)
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
        for (_, layer) in activeGlows {
            applyGlowToAllScreens(layer)
        }
    }

    // MARK: - Glow Control

    /// Triggers a glow animation for a specific app notification.
    func triggerGlow(color: NSColor, bundleIdentifier: String) {
        let layer = GlowLayer(
            color: color,
            bundleIdentifier: bundleIdentifier,
            startTime: Date()
        )

        activeGlows[bundleIdentifier] = layer
        applyGlowToAllScreens(layer)

        // Schedule auto-dismiss after the configured duration
        let duration = AppSettings.shared.glowDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.dismissGlow(for: bundleIdentifier)
        }
    }

    /// Dismisses the glow for a specific app.
    func dismissGlow(for bundleIdentifier: String) {
        activeGlows.removeValue(forKey: bundleIdentifier)
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
            let id = "test-\(index)"
            let layer = GlowLayer(
                color: color,
                bundleIdentifier: id,
                startTime: Date()
            )
            activeGlows[id] = layer
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

    private func applyGlowToAllScreens(_ layer: GlowLayer) {
        updateAllScreenGlows()
    }

    private func updateAllScreenGlows() {
        let colors = Array(activeGlows.values.map { $0.color })
        for (_, state) in glowStates {
            state.updateColors(colors)
        }
    }
}

// MARK: - Glow Layer Model

struct GlowLayer: Identifiable {
    let id = UUID()
    let color: NSColor
    let bundleIdentifier: String
    let startTime: Date
}
