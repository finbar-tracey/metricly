import XCTest
@testable import tracker

final class HealthKitSleepIntervalMergeTests: XCTestCase {

    func testMergedDurationEmpty() {
        XCTAssertEqual(HealthKitSleepIntervalMerge.mergedDuration(of: []), 0)
    }

    func testMergedDurationSingleInterval() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 3600)
        let duration = HealthKitSleepIntervalMerge.mergedDuration(of: [(start, end)])
        XCTAssertEqual(duration, 3600, accuracy: 0.001)
    }

    func testMergedDurationOverlappingIntervals() {
        let t0 = Date(timeIntervalSince1970: 0)
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 150)
        let t3 = Date(timeIntervalSince1970: 300)
        // [0,100] + [50,150] overlap → 150s; disjoint [200,300] → +100s → 250s
        let t4 = Date(timeIntervalSince1970: 200)
        let duration = HealthKitSleepIntervalMerge.mergedDuration(of: [
            (t0, t1),
            (Date(timeIntervalSince1970: 50), t2),
            (t4, t3)
        ])
        XCTAssertEqual(duration, 250, accuracy: 0.001)
    }
}
