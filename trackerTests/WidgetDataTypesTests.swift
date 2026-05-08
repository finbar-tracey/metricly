import XCTest
@testable import tracker

/// Tests for the value types nested under `WidgetDataWriter` — caffeine and
/// water snapshots used by widget extensions.
final class WidgetDataTypesTests: XCTestCase {

    // MARK: - CaffeineWidgetData.remainingMg

    func testCaffeineFullAtSameMoment() {
        let now = Date.now
        let data = WidgetDataWriter.CaffeineWidgetData(
            entries: [.init(date: now, milligrams: 100)],
            halfLifeHours: 5
        )
        XCTAssertEqual(data.remainingMg(at: now), 100, accuracy: 0.01)
    }

    func testCaffeineHalfRemainingAfterHalfLife() {
        let now = Date.now
        let earlier = now.addingTimeInterval(-5 * 3600)
        let data = WidgetDataWriter.CaffeineWidgetData(
            entries: [.init(date: earlier, milligrams: 200)],
            halfLifeHours: 5
        )
        XCTAssertEqual(data.remainingMg(at: now), 100, accuracy: 0.5)
    }

    func testCaffeineEntriesSumIndependently() {
        // Two entries spaced an hour apart — each decays from its own time.
        let now = Date.now
        let data = WidgetDataWriter.CaffeineWidgetData(
            entries: [
                .init(date: now.addingTimeInterval(-3600), milligrams: 100),
                .init(date: now,                          milligrams: 100),
            ],
            halfLifeHours: 5
        )
        // Second entry contributes the full 100 mg; first decays for 1h
        XCTAssertGreaterThan(data.remainingMg(at: now), 100)
        XCTAssertLessThan(data.remainingMg(at: now), 200)
    }

    func testCaffeineFutureEntryDoesNotContribute() {
        let now = Date.now
        let data = WidgetDataWriter.CaffeineWidgetData(
            entries: [.init(date: now.addingTimeInterval(3600), milligrams: 100)],
            halfLifeHours: 5
        )
        // Looking at "now" with a future entry — `max(0, time - date)` clamps
        // elapsed to zero, so the entry contributes its full amount. This is
        // the documented behaviour of remainingMg.
        XCTAssertEqual(data.remainingMg(at: now), 100, accuracy: 0.01)
    }

    func testCaffeineEmptyEntriesReturnsZero() {
        let data = WidgetDataWriter.CaffeineWidgetData(entries: [], halfLifeHours: 5)
        XCTAssertEqual(data.remainingMg(at: .now), 0)
    }

    // MARK: - CaffeineWidgetData.clearDate

    func testCaffeineClearDateNilWhenLowEnough() {
        let now = Date.now
        // 5 mg total — under the 10 mg "clear" threshold
        let data = WidgetDataWriter.CaffeineWidgetData(
            entries: [.init(date: now, milligrams: 5)],
            halfLifeHours: 5
        )
        XCTAssertNil(data.clearDate)
    }

    func testCaffeineClearDateInFutureWhenAboveThreshold() {
        let data = WidgetDataWriter.CaffeineWidgetData(
            entries: [.init(date: .now, milligrams: 200)],
            halfLifeHours: 5
        )
        let clear = data.clearDate
        XCTAssertNotNil(clear)
        XCTAssertGreaterThan(clear ?? .distantPast, .now,
                             "clearDate should be in the future for 200 mg")
    }

    // MARK: - WaterWidgetData

    func testWaterProgressClampsAtOne() {
        let data = WidgetDataWriter.WaterWidgetData(todayMl: 5000, goalMl: 2500)
        XCTAssertEqual(data.progress, 1.0)
    }

    func testWaterProgressZeroWhenNoIntake() {
        let data = WidgetDataWriter.WaterWidgetData(todayMl: 0, goalMl: 2500)
        XCTAssertEqual(data.progress, 0)
    }

    func testWaterProgressLinearMidway() {
        let data = WidgetDataWriter.WaterWidgetData(todayMl: 1250, goalMl: 2500)
        XCTAssertEqual(data.progress, 0.5, accuracy: 0.001)
    }

    func testWaterProgressZeroWhenGoalIsZero() {
        let data = WidgetDataWriter.WaterWidgetData(todayMl: 1000, goalMl: 0)
        XCTAssertEqual(data.progress, 0,
                       "Avoid divide-by-zero — should fall back to 0 progress")
    }

    func testWaterIsCompleteWhenAtOrAboveGoal() {
        let exact = WidgetDataWriter.WaterWidgetData(todayMl: 2500, goalMl: 2500)
        let over  = WidgetDataWriter.WaterWidgetData(todayMl: 3000, goalMl: 2500)
        let under = WidgetDataWriter.WaterWidgetData(todayMl: 2499, goalMl: 2500)
        XCTAssertTrue(exact.isComplete)
        XCTAssertTrue(over.isComplete)
        XCTAssertFalse(under.isComplete)
    }

    func testWaterFormattedSwitchesToLitresAtThousand() {
        let small = WidgetDataWriter.WaterWidgetData(todayMl: 500, goalMl: 2500)
        let large = WidgetDataWriter.WaterWidgetData(todayMl: 2000, goalMl: 2500)
        XCTAssertEqual(small.formattedToday, "500 ml")
        XCTAssertEqual(large.formattedToday, "2.0L")
    }

    func testWaterFormattedGoalUnits() {
        let data = WidgetDataWriter.WaterWidgetData(todayMl: 0, goalMl: 2500)
        XCTAssertEqual(data.formattedGoal, "2.5L")
    }
}
