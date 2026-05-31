import XCTest
@testable import tracker

final class SyncStatusManagerTests: XCTestCase {

    func testAccountStatusLabels() {
        XCTAssertEqual(SyncStatusManager.AccountStatus.available.label, "iCloud signed in")
        XCTAssertEqual(SyncStatusManager.AccountStatus.noAccount.label, "No iCloud account")
        XCTAssertTrue(SyncStatusManager.AccountStatus.available.isHealthy)
        XCTAssertFalse(SyncStatusManager.AccountStatus.restricted.isHealthy)
    }

    func testFormatLastSyncNeverWhenUnset() {
        XCTAssertEqual(SyncStatusManager.formatLastSync(since: nil), "Never")
    }

    func testFormattedLastSyncAfterRecordedDate() {
        let manager = SyncStatusManager.shared
        let past = Date(timeIntervalSinceNow: -7200)
        manager.recordSuccessfulSyncForTesting(at: past)
        XCTAssertNotEqual(manager.formattedLastSync, "Never")
        XCTAssertFalse(manager.formattedLastSync.isEmpty)
    }

    func testSyncingFlagTransition() {
        let manager = SyncStatusManager.shared
        manager.setSyncingForTesting(true)
        XCTAssertTrue(manager.isSyncing)
        manager.setSyncingForTesting(false)
        XCTAssertFalse(manager.isSyncing)
    }
}
