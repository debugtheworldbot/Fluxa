import Foundation
import AppKit

// MARK: - App Configuration

/// Configuration for a single monitored application.
struct AppConfiguration: Codable, Identifiable {
    var id: String { bundleIdentifier }
    let bundleIdentifier: String
    var displayName: String
    var isEnabled: Bool
    var colorHex: String

    var color: NSColor {
        get { NSColor(hex: colorHex) ?? .systemBlue }
        set { colorHex = newValue.toHex() }
    }

    enum CodingKeys: String, CodingKey {
        case bundleIdentifier, displayName, isEnabled, colorHex
    }
}

// MARK: - App Settings

/// Centralized, persisted settings for the application.
final class AppSettings: ObservableObject {

    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let appConfigurations = "appConfigurations"
        static let glowDuration = "glowDuration"
        static let glowWidth = "glowWidth"
        static let animationSpeed = "animationSpeed"
        static let pulseIntensity = "pulseIntensity"
        static let launchAtLogin = "launchAtLogin"
        static let didDisableAllAppsByDefaultMigration = "didDisableAllAppsByDefaultMigration"
    }

    // MARK: - Onboarding

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    // MARK: - App Configurations

    @Published var appConfigurations: [String: AppConfiguration] {
        didSet { saveAppConfigurations() }
    }

    // MARK: - Animation Settings

    /// How long the glow persists after a notification (seconds).
    @Published var glowDuration: TimeInterval {
        didSet { defaults.set(glowDuration, forKey: Keys.glowDuration) }
    }

    /// Width of the core glow line in points.
    @Published var glowWidth: CGFloat {
        didSet { defaults.set(Double(glowWidth), forKey: Keys.glowWidth) }
    }

    /// Speed of the gradient rotation (revolutions per second).
    @Published var animationSpeed: CGFloat {
        didSet { defaults.set(Double(animationSpeed), forKey: Keys.animationSpeed) }
    }

    /// Intensity of the breathing pulse effect (0.0 - 1.0).
    @Published var pulseIntensity: CGFloat {
        didSet { defaults.set(Double(pulseIntensity), forKey: Keys.pulseIntensity) }
    }

    /// Whether to launch at login.
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    // MARK: - Default Colors

    /// A palette of visually distinct default colors for auto-assignment.
    static let defaultColorPalette: [String] = [
        "#7B61FF",  // Purple
        "#FF6B6B",  // Coral Red
        "#4ECDC4",  // Teal
        "#FFE66D",  // Yellow
        "#FF8A5C",  // Orange
        "#A8E6CF",  // Mint
        "#FF71CE",  // Pink
        "#01CDFE",  // Cyan
        "#05FFA1",  // Green
        "#B967FF",  // Violet
        "#FFFB96",  // Light Yellow
        "#F38181",  // Salmon
    ]

    private var colorAssignmentIndex: Int = 0

    // MARK: - Init

    private init() {
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.glowDuration = defaults.double(forKey: Keys.glowDuration).nonZero ?? 8.0
        self.glowWidth = CGFloat(defaults.double(forKey: Keys.glowWidth).nonZero ?? 4.0)
        self.animationSpeed = CGFloat(defaults.double(forKey: Keys.animationSpeed).nonZero ?? 0.15)
        self.pulseIntensity = CGFloat(defaults.double(forKey: Keys.pulseIntensity).nonZero ?? 0.5)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.appConfigurations = [:]
        self.appConfigurations = loadAppConfigurations()
        migrateDisableAllAppsByDefaultIfNeeded()
    }

    // MARK: - App Configuration Management

    /// Registers a new app with a default color if it doesn't already exist.
    func registerAppIfNeeded(bundleIdentifier: String) {
        guard appConfigurations[bundleIdentifier] == nil else { return }

        let displayName = Self.resolveAppName(for: bundleIdentifier)
        let colorHex = Self.defaultColorPalette[colorAssignmentIndex % Self.defaultColorPalette.count]
        colorAssignmentIndex += 1

        let config = AppConfiguration(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            isEnabled: false,
            colorHex: colorHex
        )

        appConfigurations[bundleIdentifier] = config
    }

    // MARK: - Persistence

    private func saveAppConfigurations() {
        if let data = try? JSONEncoder().encode(appConfigurations) {
            defaults.set(data, forKey: Keys.appConfigurations)
        }
    }

    private func loadAppConfigurations() -> [String: AppConfiguration] {
        guard let data = defaults.data(forKey: Keys.appConfigurations),
              let configs = try? JSONDecoder().decode([String: AppConfiguration].self, from: data) else {
            return [:]
        }
        return configs
    }

    /// One-time migration: ensure existing persisted app entries start disabled.
    private func migrateDisableAllAppsByDefaultIfNeeded() {
        guard !defaults.bool(forKey: Keys.didDisableAllAppsByDefaultMigration) else { return }

        appConfigurations = appConfigurations.mapValues { config in
            var updated = config
            updated.isEnabled = false
            return updated
        }

        defaults.set(true, forKey: Keys.didDisableAllAppsByDefaultMigration)
    }

    // MARK: - Helpers

    /// Resolves a human-readable app name from a bundle identifier.
    static func resolveAppName(for bundleIdentifier: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            let name = appURL.deletingPathExtension().lastPathComponent
            if !name.isEmpty { return name }
        }

        // Fallback: extract the last component of the bundle ID
        let components = bundleIdentifier.split(separator: ".")
        return components.last.map(String.init) ?? bundleIdentifier
    }
}

// MARK: - Double Extension

private extension Double {
    var nonZero: Double? {
        return self == 0 ? nil : self
    }
}

// MARK: - NSColor Hex Extensions

extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        guard hexSanitized.count == 6 else { return nil }

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        self.init(
            red: CGFloat((rgb & 0xFF0000) >> 16) / 255.0,
            green: CGFloat((rgb & 0x00FF00) >> 8) / 255.0,
            blue: CGFloat(rgb & 0x0000FF) / 255.0,
            alpha: 1.0
        )
    }

    func toHex() -> String {
        guard let rgbColor = usingColorSpace(.sRGB) else { return "#007AFF" }
        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
