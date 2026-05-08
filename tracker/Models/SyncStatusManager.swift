import Foundation
import CoreData
import CloudKit
import Observation

/// Watches CloudKit account status and SwiftData → CloudKit sync events so the
/// app can show users a visible "data is being backed up" indicator.
///
/// Surfaces three pieces of information:
/// 1. iCloud account availability (signed in / restricted / no account)
/// 2. Whether a sync is currently in progress
/// 3. When the last successful sync completed (any direction — import or export)
///
/// SwiftData with `cloudKitDatabase: .automatic` uses an underlying
/// `NSPersistentCloudKitContainer` whose events are posted as
/// `eventChangedNotification`. We listen for those.
@Observable
final class SyncStatusManager {

    // MARK: - Public state

    enum AccountStatus {
        case unknown, available, restricted, noAccount, temporarilyUnavailable

        var label: String {
            switch self {
            case .unknown:                return "Checking…"
            case .available:              return "iCloud signed in"
            case .restricted:             return "iCloud restricted"
            case .noAccount:              return "No iCloud account"
            case .temporarilyUnavailable: return "iCloud unavailable"
            }
        }

        var isHealthy: Bool { self == .available }
    }

    static let shared = SyncStatusManager()

    private(set) var accountStatus: AccountStatus = .unknown
    /// True while a CloudKit import or export is actively running.
    private(set) var isSyncing: Bool = false
    /// Most recent successful sync of any kind. Persists across launches.
    private(set) var lastSuccessfulSync: Date?
    /// If the last sync attempt failed, the error message to display.
    private(set) var lastError: String?

    // MARK: - Private

    private let lastSyncKey = "lastSuccessfulCloudKitSync"
    private let suiteName = "group.com.Finbar.FinApp"
    private var observers: [NSObjectProtocol] = []

    private init() {
        // Hydrate from persisted store
        let ts = UserDefaults(suiteName: suiteName)?.double(forKey: lastSyncKey) ?? 0
        if ts > 0 {
            lastSuccessfulSync = Date(timeIntervalSince1970: ts)
        }

        startObserving()
        Task { await refreshAccountStatus() }
    }

    deinit {
        for o in observers { NotificationCenter.default.removeObserver(o) }
    }

    // MARK: - Account status

    /// Re-query iCloud account status. Call this on app foreground.
    func refreshAccountStatus() async {
        let container = CKContainer.default()
        do {
            let status = try await container.accountStatus()
            await MainActor.run {
                self.accountStatus = Self.map(status)
            }
        } catch {
            await MainActor.run {
                self.accountStatus = .unknown
            }
        }
    }

    private static func map(_ status: CKAccountStatus) -> AccountStatus {
        switch status {
        case .available:              return .available
        case .restricted:             return .restricted
        case .noAccount:              return .noAccount
        case .temporarilyUnavailable: return .temporarilyUnavailable
        case .couldNotDetermine:      return .unknown
        @unknown default:             return .unknown
        }
    }

    // MARK: - Sync events

    private func startObserving() {
        // SwiftData → CloudKit progress events
        let eventToken = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleEvent(notification)
        }
        observers.append(eventToken)

        // Refresh account status when iCloud account changes (e.g. sign in/out)
        let accountToken = NotificationCenter.default.addObserver(
            forName: .CKAccountChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshAccountStatus() }
        }
        observers.append(accountToken)
    }

    private func handleEvent(_ notification: Notification) {
        guard let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                as? NSPersistentCloudKitContainer.Event
        else { return }

        if event.endDate == nil {
            // In progress
            isSyncing = true
            return
        }

        // Event finished
        isSyncing = false

        if event.succeeded {
            let now = Date.now
            lastSuccessfulSync = now
            lastError = nil
            UserDefaults(suiteName: suiteName)?.set(now.timeIntervalSince1970, forKey: lastSyncKey)
        } else if let error = event.error {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Display helpers

    /// Human-friendly "last synced X ago" string. Returns "Never" if no
    /// successful sync has been recorded.
    var formattedLastSync: String {
        guard let date = lastSuccessfulSync else { return "Never" }
        return date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
