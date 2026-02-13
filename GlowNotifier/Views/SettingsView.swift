import SwiftUI
import AppKit

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var appSettings: AppSettings
    @ObservedObject var overlayManager: OverlayWindowManager
    @ObservedObject var notificationEngine: NotificationEngine

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            AppsSettingsTab(appSettings: appSettings, notificationEngine: notificationEngine)
                .tabItem { Label("Apps", systemImage: "app.badge") }
                .tag(0)

            AnimationSettingsTab(appSettings: appSettings, overlayManager: overlayManager)
                .tabItem { Label("Animation", systemImage: "wand.and.stars") }
                .tag(1)

            StatusTab(notificationEngine: notificationEngine)
                .tabItem { Label("Status", systemImage: "heart.text.square") }
                .tag(2)

            GeneralSettingsTab(appSettings: appSettings)
                .tabItem { Label("General", systemImage: "gear") }
                .tag(3)
        }
        .frame(minWidth: 540, minHeight: 400)
        .padding()
    }
}

// MARK: - Apps Settings Tab

struct AppsSettingsTab: View {

    @ObservedObject var appSettings: AppSettings
    @ObservedObject var notificationEngine: NotificationEngine

    @State private var searchText = ""

    private static let prioritizedBundleIds: Set<String> = [
        "com.tinyspeck.slackmacgap",
        "ru.keepcoder.Telegram",
        "com.apple.mail",
        "com.microsoft.Outlook",
        "com.microsoft.OutlookLegacy",
        "com.microsoft.teams",
        "com.microsoft.teams2",
        "com.hnc.Discord",
        "com.tencent.xinWeChat",
        "com.tencent.qq",
        "com.readdle.smartemail-Mac",
        "it.bloop.airmail2",
        "com.mimestream.Mimestream"
    ]

    private static let prioritizedNameKeywords: [String] = [
        "slack",
        "telegram",
        "mail",
        "outlook",
        "teams",
        "discord",
        "wechat",
        "qq",
        "spark",
        "airmail",
        "mimestream"
    ]

    var filteredApps: [AppConfiguration] {
        let allConfigs = Array(appSettings.appConfigurations.values)
        let iconAvailability = Dictionary(
            uniqueKeysWithValues: allConfigs.map { config in
                (config.bundleIdentifier, hasAppIcon(for: config.bundleIdentifier))
            }
        )

        let allApps = allConfigs.sorted { lhs, rhs in
                if lhs.isEnabled != rhs.isEnabled {
                    return lhs.isEnabled && !rhs.isEnabled
                }

                if lhs.isEnabled && rhs.isEnabled {
                    let lhsEnabledAt = lhs.enabledAt ?? .distantPast
                    let rhsEnabledAt = rhs.enabledAt ?? .distantPast
                    if lhsEnabledAt != rhsEnabledAt {
                        return lhsEnabledAt < rhsEnabledAt
                    }
                }

                let lhsHasIcon = iconAvailability[lhs.bundleIdentifier] ?? false
                let rhsHasIcon = iconAvailability[rhs.bundleIdentifier] ?? false
                if lhsHasIcon != rhsHasIcon {
                    return lhsHasIcon && !rhsHasIcon
                }

                let lhsPriority = appPriority(for: lhs)
                let rhsPriority = appPriority(for: rhs)
                if lhsPriority != rhsPriority {
                    return lhsPriority < rhsPriority
                }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }

        if searchText.isEmpty {
            return allApps
        }
        return allApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func appPriority(for config: AppConfiguration) -> Int {
        if Self.prioritizedBundleIds.contains(config.bundleIdentifier) {
            return 0
        }

        let searchableText = "\(config.displayName) \(config.bundleIdentifier)".lowercased()
        if Self.prioritizedNameKeywords.contains(where: { searchableText.contains($0) }) {
            return 0
        }

        return 1
    }

    private func hasAppIcon(for bundleIdentifier: String) -> Bool {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Monitored Applications")
                    .font(.headline)

                Spacer()

                Button("Discover Apps") {
                    discoverApps()
                }
            }

            TextField("Search apps...", text: $searchText)
                .textFieldStyle(.roundedBorder)

            if filteredApps.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "app.dashed")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No apps configured yet.")
                        .foregroundColor(.secondary)
                    Text("Click \"Discover Apps\" to scan for apps that have sent notifications.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(filteredApps) { config in
                        AppConfigRow(config: config, appSettings: appSettings)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
            }
        }
        .padding()
        .onAppear {
            discoverApps()
        }
    }

    private func discoverApps() {
        let knownBundleIds = notificationEngine.fetchKnownApps()
        for bundleId in knownBundleIds {
            appSettings.registerAppIfNeeded(bundleIdentifier: bundleId)
        }
    }
}

// MARK: - App Config Row

struct AppConfigRow: View {

    let config: AppConfiguration
    @ObservedObject var appSettings: AppSettings

    @State private var isEnabled: Bool
    @State private var selectedColor: Color

    init(config: AppConfiguration, appSettings: AppSettings) {
        self.config = config
        self.appSettings = appSettings
        self._isEnabled = State(initialValue: config.isEnabled)
        self._selectedColor = State(initialValue: Color(nsColor: config.color))
    }

    var body: some View {
        HStack(spacing: 12) {
            // App icon
            AppIconView(bundleIdentifier: config.bundleIdentifier)
                .frame(width: 32, height: 32)

            // App name and bundle ID
            VStack(alignment: .leading, spacing: 2) {
                Text(config.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                Text(config.bundleIdentifier)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Color picker
            ColorPicker("", selection: $selectedColor, supportsOpacity: false)
                .labelsHidden()
                .frame(width: 30)
                .onChange(of: selectedColor) { newColor in
                    var updated = config
                    updated.colorHex = NSColor(newColor).toHex()
                    appSettings.appConfigurations[config.bundleIdentifier] = updated
                }

            // Enable/disable toggle
            Toggle("", isOn: $isEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .onChange(of: isEnabled) { newValue in
                    var updated = config
                    updated.isEnabled = newValue
                    updated.enabledAt = newValue ? Date() : nil
                    appSettings.appConfigurations[config.bundleIdentifier] = updated
                }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - App Icon View

struct AppIconView: View {

    let bundleIdentifier: String

    var body: some View {
        if let icon = appIcon {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "app.fill")
                .font(.title2)
                .foregroundColor(.secondary)
        }
    }

    private var appIcon: NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
}

// MARK: - Animation Settings Tab

struct AnimationSettingsTab: View {

    @ObservedObject var appSettings: AppSettings
    @ObservedObject var overlayManager: OverlayWindowManager

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Animation Settings")
                .font(.headline)

            GroupBox("Glow Appearance") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Glow Width")
                            .frame(width: 120, alignment: .leading)
                        Slider(value: $appSettings.glowWidth, in: 1.0...12.0, step: 0.5)
                        Text("\(appSettings.glowWidth, specifier: "%.1f") pt")
                            .frame(width: 50)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Rotation Speed")
                            .frame(width: 120, alignment: .leading)
                        Slider(value: $appSettings.animationSpeed, in: 0.02...0.5, step: 0.01)
                        Text("\(appSettings.animationSpeed, specifier: "%.2f")")
                            .frame(width: 50)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Pulse Intensity")
                            .frame(width: 120, alignment: .leading)
                        Slider(value: $appSettings.pulseIntensity, in: 0.0...1.0, step: 0.05)
                        Text("\(appSettings.pulseIntensity, specifier: "%.0f")%")
                            .frame(width: 50)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }

            GroupBox("Behavior") {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Glow Duration")
                            .frame(width: 120, alignment: .leading)
                        Slider(value: $appSettings.glowDuration, in: 2.0...30.0, step: 1.0)
                        Text("\(Int(appSettings.glowDuration))s")
                            .frame(width: 50)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("Test Animation") {
                    overlayManager.triggerTestGlow()
                }
                .controlSize(.large)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Status Tab

struct StatusTab: View {

    @ObservedObject var notificationEngine: NotificationEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Monitoring Status")
                .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    StatusRow(
                        label: "Database Access",
                        value: notificationEngine.hasAccess ? "Granted" : "Not Granted",
                        color: notificationEngine.hasAccess ? .green : .red
                    )

                    StatusRow(
                        label: "Monitoring Active",
                        value: notificationEngine.isMonitoring ? "Running" : "Stopped",
                        color: notificationEngine.isMonitoring ? .green : .orange
                    )

                    StatusRow(
                        label: "Session Events",
                        value: "\(notificationEngine.sessionEventCount)",
                        color: .primary
                    )

                    if let lastEvent = notificationEngine.lastEventTime {
                        StatusRow(
                            label: "Last Event",
                            value: lastEvent.formatted(date: .abbreviated, time: .standard),
                            color: .primary
                        )
                    }
                }
                .padding(8)
            }

            if !notificationEngine.hasAccess {
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Full Disk Access Required", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.headline)

                        Text("GlowNotifier needs Full Disk Access to read the notification database. Please grant it in System Settings.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button("Open System Settings") {
                            openFullDiskAccessSettings()
                        }
                        .padding(.top, 4)
                    }
                    .padding(8)
                }
            }

            HStack {
                Button("Recheck Permissions") {
                    notificationEngine.recheckAccess()
                }

                Spacer()

                if notificationEngine.isMonitoring {
                    Button("Stop Monitoring") {
                        notificationEngine.stopMonitoring()
                    }
                } else {
                    Button("Start Monitoring") {
                        notificationEngine.startMonitoring()
                    }
                }
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - General Settings Tab

struct GeneralSettingsTab: View {

    @ObservedObject var appSettings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("General Settings")
                .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at Login", isOn: $appSettings.launchAtLogin)

                    Text("When enabled, GlowNotifier will start automatically when you log in.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox("About") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("GlowNotifier v1.0.0")
                        .font(.body)
                        .fontWeight(.medium)

                    Text("A macOS app that displays animated screen border glows when notifications arrive. Each app gets its own color, creating a beautiful rainbow effect.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            Spacer()
        }
        .padding()
    }
}

// MARK: - Status Row

struct StatusRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 140, alignment: .leading)
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Helpers

func openFullDiskAccessSettings() {
    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
        NSWorkspace.shared.open(url)
    }
}
