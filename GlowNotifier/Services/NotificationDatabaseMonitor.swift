import Foundation

// MARK: - Notification Database Monitor

/// Monitors the macOS notification center SQLite database for changes using
/// a combination of FSEvents (directory-level) and a polling fallback.
///
/// Database location (macOS Sequoia+):
///   ~/Library/Group Containers/group.com.apple.usernoted/db2/db
///
/// Requires Full Disk Access to read this TCC-protected path.
final class NotificationDatabaseMonitor {

    // MARK: - Properties

    private var fsEventStream: FSEventStreamRef?
    private var pollingTimer: Timer?
    private var lastModificationDate: Date?
    private var isRunning = false

    /// Callback fired when a database change is detected.
    var onDatabaseChanged: (() -> Void)?

    /// The path to the notification database.
    var databasePath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/Library/Group Containers/group.com.apple.usernoted/db2/db"
    }

    /// The directory containing the database (watched by FSEvents).
    private var databaseDirectory: String {
        return (databasePath as NSString).deletingLastPathComponent
    }

    // MARK: - Lifecycle

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Record initial modification date
        lastModificationDate = fileModificationDate(at: databasePath)

        // Start FSEvents stream
        startFSEventStream()

        // Start polling fallback (handles WAL changes that FSEvents may miss)
        startPollingFallback()

        print("[NotificationDatabaseMonitor] Started monitoring: \(databasePath)")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        stopFSEventStream()
        stopPollingFallback()

        print("[NotificationDatabaseMonitor] Stopped monitoring.")
    }

    // MARK: - Permission Check

    /// Checks whether the app has access to the notification database.
    func canAccessDatabase() -> Bool {
        return FileManager.default.isReadableFile(atPath: databasePath)
    }

    // MARK: - FSEvents Stream

    private func startFSEventStream() {
        let pathsToWatch = [databaseDirectory] as CFArray

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let flags: FSEventStreamCreateFlags =
            UInt32(kFSEventStreamCreateFlagUseCFTypes) |
            UInt32(kFSEventStreamCreateFlagFileEvents) |
            UInt32(kFSEventStreamCreateFlagNoDefer)

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,  // latency in seconds
            flags
        ) else {
            print("[NotificationDatabaseMonitor] Failed to create FSEvent stream.")
            return
        }

        fsEventStream = stream
        FSEventStreamScheduleWithRunLoop(stream, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        FSEventStreamStart(stream)
    }

    private func stopFSEventStream() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }

    // MARK: - Polling Fallback

    /// A lightweight polling mechanism that checks the database modification
    /// timestamp every 2 seconds. This catches changes that FSEvents may miss,
    /// particularly SQLite WAL file modifications.
    private func startPollingFallback() {
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
    }

    private func stopPollingFallback() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - Change Detection

    fileprivate func handleFSEvent() {
        checkForChanges()
    }

    private func checkForChanges() {
        guard isRunning else { return }

        // Check the main db file and the WAL file
        let dbDate = fileModificationDate(at: databasePath)
        let walDate = fileModificationDate(at: databasePath + "-wal")

        let latestDate = [dbDate, walDate].compactMap { $0 }.max()

        guard let latest = latestDate else { return }

        if let last = lastModificationDate {
            if latest > last {
                lastModificationDate = latest
                DispatchQueue.main.async { [weak self] in
                    self?.onDatabaseChanged?()
                }
            }
        } else {
            lastModificationDate = latest
        }
    }

    // MARK: - Utilities

    private func fileModificationDate(at path: String) -> Date? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
}

// MARK: - FSEvents C Callback

private func fsEventCallback(
    streamRef: ConstFSEventStreamRef,
    clientCallBackInfo: UnsafeMutableRawPointer?,
    numEvents: Int,
    eventPaths: UnsafeMutableRawPointer,
    eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let monitor = Unmanaged<NotificationDatabaseMonitor>.fromOpaque(info).takeUnretainedValue()
    monitor.handleFSEvent()
}
