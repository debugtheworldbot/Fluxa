import Foundation

// MARK: - Notification Engine

/// The central coordinator that connects the database monitor to the rest of the app.
/// It receives file change events, triggers the parser, identifies the source application,
/// and dispatches notification events to the overlay manager.
final class NotificationEngine: ObservableObject {

    // MARK: - Properties

    private let databaseMonitor = NotificationDatabaseMonitor()
    private lazy var databaseParser = NotificationDatabaseParser(
        databasePath: databaseMonitor.databasePath
    )

    /// Callback fired when a new notification is detected.
    var onNotification: ((NotificationEvent) -> Void)?

    /// Whether the engine is currently monitoring.
    @Published var isMonitoring: Bool = false

    /// Whether the app has database access.
    @Published var hasAccess: Bool = false

    /// Timestamp of the last detected notification.
    @Published var lastEventTime: Date?

    /// Total number of notifications detected in this session.
    @Published var sessionEventCount: Int = 0

    // MARK: - Lifecycle

    func startMonitoring() {
        guard !isMonitoring else { return }

        // Check access first
        hasAccess = databaseMonitor.canAccessDatabase()
        guard hasAccess else {
            print("[NotificationEngine] Cannot access notification database. Full Disk Access required.")
            return
        }

        // Initialize parser to skip existing records
        databaseParser.initializeLastRecordId()

        // Connect the monitor callback
        databaseMonitor.onDatabaseChanged = { [weak self] in
            self?.handleDatabaseChange()
        }

        // Start monitoring
        databaseMonitor.start()
        isMonitoring = true

        print("[NotificationEngine] Monitoring started.")
    }

    func stopMonitoring() {
        databaseMonitor.stop()
        isMonitoring = false
        print("[NotificationEngine] Monitoring stopped.")
    }

    /// Re-checks database access permission.
    func recheckAccess() {
        hasAccess = databaseMonitor.canAccessDatabase()
    }

    /// Returns the list of known app bundle identifiers from the database.
    func fetchKnownApps() -> [String] {
        return databaseParser.fetchKnownAppBundleIds()
    }

    // MARK: - Internal

    private func handleDatabaseChange() {
        let newEvents = databaseParser.fetchNewNotifications()

        for event in newEvents {
            sessionEventCount += 1
            lastEventTime = event.deliveredDate

            print("[NotificationEngine] New notification from: \(event.bundleIdentifier)")

            onNotification?(event)
        }
    }
}
