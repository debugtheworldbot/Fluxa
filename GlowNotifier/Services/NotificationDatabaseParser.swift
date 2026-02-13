import Foundation
import SQLite3

// MARK: - Notification Event

/// Represents a single parsed notification event from the database.
struct NotificationEvent: Identifiable, Equatable {
    let id: Int64
    let bundleIdentifier: String
    let deliveredDate: Date
    let title: String?
    let subtitle: String?

    static func == (lhs: NotificationEvent, rhs: NotificationEvent) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Notification Database Parser

/// Reads and parses the macOS notification center SQLite database.
/// Opens the database in read-only mode to avoid interfering with the system.
final class NotificationDatabaseParser {

    private let databasePath: String

    /// Tracks the last processed record ID to avoid re-processing.
    private var lastProcessedRecordId: Int64 = 0

    init(databasePath: String) {
        self.databasePath = databasePath
    }

    // MARK: - Public API

    /// Fetches new notification records since the last check.
    /// Returns an array of `NotificationEvent` objects.
    func fetchNewNotifications() -> [NotificationEvent] {
        var db: OpaquePointer?

        // Open in read-only mode with URI to handle WAL correctly
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        let uri = "file:\(databasePath)?mode=ro&immutable=0"

        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK else {
            let errorMsg = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            print("[NotificationDatabaseParser] Failed to open database: \(errorMsg)")
            sqlite3_close(db)
            return []
        }

        defer { sqlite3_close(db) }

        // Enable WAL mode reading
        sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil)

        var events: [NotificationEvent] = []

        // Query for new records since last processed ID
        let query = """
            SELECT rec_id, app_id, delivered_date, data
            FROM record
            WHERE rec_id > ?
            ORDER BY delivered_date DESC
            LIMIT 20;
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            let errorMsg = String(cString: sqlite3_errmsg(db!))
            print("[NotificationDatabaseParser] Failed to prepare query: \(errorMsg)")
            return []
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, lastProcessedRecordId)

        while sqlite3_step(statement) == SQLITE_ROW {
            let recId = sqlite3_column_int64(statement, 0)
            let appId = sqlite3_column_int64(statement, 1)

            let deliveredDateTimestamp = sqlite3_column_double(statement, 2)
            // Apple's Core Data timestamp: seconds since 2001-01-01
            let deliveredDate = Date(timeIntervalSinceReferenceDate: deliveredDateTimestamp)

            // Parse the notification data blob (binary plist)
            var title: String?
            var subtitle: String?
            if let dataBlob = sqlite3_column_blob(statement, 3) {
                let dataLength = sqlite3_column_bytes(statement, 3)
                let data = Data(bytes: dataBlob, count: Int(dataLength))
                let parsed = parseNotificationData(data)
                title = parsed.title
                subtitle = parsed.subtitle
            }

            // Resolve bundle identifier from app_id
            let bundleId = resolveBundleIdentifier(db: db!, appId: appId)

            if let bundleId = bundleId {
                let event = NotificationEvent(
                    id: recId,
                    bundleIdentifier: bundleId,
                    deliveredDate: deliveredDate,
                    title: title,
                    subtitle: subtitle
                )
                events.append(event)
            }

            if recId > lastProcessedRecordId {
                lastProcessedRecordId = recId
            }
        }

        return events
    }

    /// Fetches all known app bundle identifiers from the database.
    func fetchKnownAppBundleIds() -> [String] {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        let uri = "file:\(databasePath)?mode=ro&immutable=0"

        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return []
        }

        defer { sqlite3_close(db) }

        var bundleIds: [String] = []
        let query = "SELECT DISTINCT identifier FROM app;"

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return []
        }

        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                bundleIds.append(String(cString: cString))
            }
        }

        return bundleIds
    }

    /// Initializes the last processed record ID to the current maximum,
    /// so we only process new notifications going forward.
    func initializeLastRecordId() {
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI
        let uri = "file:\(databasePath)?mode=ro&immutable=0"

        guard sqlite3_open_v2(uri, &db, flags, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return
        }

        defer { sqlite3_close(db) }

        let query = "SELECT MAX(rec_id) FROM record;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return
        }

        defer { sqlite3_finalize(statement) }

        if sqlite3_step(statement) == SQLITE_ROW {
            lastProcessedRecordId = sqlite3_column_int64(statement, 0)
        }

        print("[NotificationDatabaseParser] Initialized last record ID: \(lastProcessedRecordId)")
    }

    // MARK: - Internal Helpers

    /// Resolves a bundle identifier from the `app` table using the app_id foreign key.
    private func resolveBundleIdentifier(db: OpaquePointer, appId: Int64) -> String? {
        let query = "SELECT identifier FROM app WHERE app_id = ?;"
        var statement: OpaquePointer?

        guard sqlite3_prepare_v2(db, query, -1, &statement, nil) == SQLITE_OK else {
            return nil
        }

        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, appId)

        if sqlite3_step(statement) == SQLITE_ROW {
            if let cString = sqlite3_column_text(statement, 0) {
                return String(cString: cString)
            }
        }

        return nil
    }

    /// Attempts to parse the binary plist notification data blob to extract
    /// the title and subtitle fields.
    private func parseNotificationData(_ data: Data) -> (title: String?, subtitle: String?) {
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any] else {
            return (nil, nil)
        }

        // The notification data structure varies, but commonly includes these keys
        let title = plist["titl"] as? String ?? plist["title"] as? String
        let subtitle = plist["subt"] as? String ?? plist["subtitle"] as? String ?? plist["body"] as? String

        return (title, subtitle)
    }
}
