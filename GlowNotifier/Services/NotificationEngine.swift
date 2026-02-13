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
    var onNotificationAdded: ((NotificationEvent) -> Void)?

    /// Callback fired when a tracked notification is dismissed/read.
    var onNotificationRemoved: ((Int64) -> Void)?

    /// Notification IDs currently tracked for lifecycle updates.
    private var trackedNotificationIds: Set<Int64> = []

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
            trackedNotificationIds.insert(event.id)

            print("[NotificationEngine] New notification from: \(event.bundleIdentifier)")

            onNotificationAdded?(event)
        }

        guard !trackedNotificationIds.isEmpty else { return }

        let existingIds = databaseParser.fetchExistingNotificationIds(from: trackedNotificationIds)
        let removedIds = trackedNotificationIds.subtracting(existingIds)

        for removedId in removedIds {
            print("[NotificationEngine] Notification removed/read: \(removedId)")
            onNotificationRemoved?(removedId)
        }

        trackedNotificationIds = existingIds
    }
}
