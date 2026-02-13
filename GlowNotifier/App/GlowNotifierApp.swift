import SwiftUI
import AppKit

// MARK: - App Entry Point

@main
struct GlowNotifierApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusBarController: StatusBarController?
    private var overlayManager: OverlayWindowManager?
    private var notificationEngine: NotificationEngine?
    private var onboardingWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Initialize core services
        let appSettings = AppSettings.shared
        overlayManager = OverlayWindowManager()
        notificationEngine = NotificationEngine()

        // Initialize status bar
        statusBarController = StatusBarController(
            appSettings: appSettings,
            overlayManager: overlayManager!,
            notificationEngine: notificationEngine!
        )

        // Connect notification engine to overlay manager
        notificationEngine?.onNotification = { [weak self] event in
            self?.handleNotification(event)
        }

        // Check permissions and show onboarding if needed
        if !appSettings.hasCompletedOnboarding {
            showOnboarding()
        } else {
            startMonitoring()
        }
    }

    private func handleNotification(_ event: NotificationEvent) {
        let settings = AppSettings.shared
        guard let appConfig = settings.appConfigurations[event.bundleIdentifier],
              appConfig.isEnabled else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.overlayManager?.triggerGlow(
                color: appConfig.color,
                bundleIdentifier: event.bundleIdentifier
            )
        }
    }

    private func startMonitoring() {
        notificationEngine?.startMonitoring()
    }

    func showOnboarding() {
        if onboardingWindow != nil { return }

        let onboardingView = OnboardingView {
            AppSettings.shared.hasCompletedOnboarding = true
            self.onboardingWindow?.close()
            self.onboardingWindow = nil
            self.startMonitoring()
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to GlowNotifier"
        window.contentView = NSHostingView(rootView: onboardingView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        onboardingWindow = window
    }
}
