import XCTest
@testable import tracker

@MainActor
final class CardioTrackerTests: XCTestCase {

    func testEstimatedCaloriesOutdoorRun() {
        let t = CardioTracker()
        t.elapsedSeconds = 3600                 // 1 hour, default type .outdoorRun (MET 9.8)
        XCTAssertEqual(t.estimatedCalories(bodyWeightKg: 70), 9.8 * 70, accuracy: 0.01)
    }

    func testEstimatedCaloriesScalesWithDuration() {
        let t = CardioTracker()
        t.elapsedSeconds = 1800                 // 30 min
        XCTAssertEqual(t.estimatedCalories(bodyWeightKg: 80), 9.8 * 80 * 0.5, accuracy: 0.01)
    }

    func testFormattedCurrentPaceFormatsMinutesSeconds() {
        let t = CardioTracker()
        t.currentPaceSecPerKm = 5 * 60 + 30     // 5:30 /km
        XCTAssertEqual(t.formattedCurrentPace(useKm: true), "5:30")
    }

    func testFormattedCurrentPaceInvalidReturnsDashes() {
        let t = CardioTracker()
        t.currentPaceSecPerKm = 0
        XCTAssertEqual(t.formattedCurrentPace(useKm: true), "--:--")
        t.currentPaceSecPerKm = 2000            // ≥ 1800 sentinel
        XCTAssertEqual(t.formattedCurrentPace(useKm: true), "--:--")
    }

    func testFormattedDistanceKmAndMiles() {
        let t = CardioTracker()
        t.distanceMeters = 5000
        XCTAssertEqual(t.formattedDistance(useKm: true), "5.00")
        XCTAssertEqual(t.formattedDistance(useKm: false), "3.11")  // 5000 / 1609.344
    }

    func testFormattedElapsedWithAndWithoutHours() {
        let t = CardioTracker()
        t.elapsedSeconds = 90
        XCTAssertEqual(t.formattedElapsed, "1:30")
        t.elapsedSeconds = 3661
        XCTAssertEqual(t.formattedElapsed, "1:01:01")
    }
}
