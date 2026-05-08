import XCTest
@testable import tracker

final class CaffeineDecayTests: XCTestCase {

    /// Tolerance for floating-point comparisons of mg values (1% relative).
    private func XCTAssertCloseEnough(_ a: Double, _ b: Double, tolerance: Double = 0.5,
                                       file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a, b, accuracy: tolerance, file: file, line: line)
    }

    // MARK: - At time of consumption

    func testFullAmountAtConsumption() {
        let entry = CaffeineEntry(date: .now, milligrams: 100, source: "Coffee")
        XCTAssertCloseEnough(entry.remainingCaffeine(at: .now), 100)
    }

    // MARK: - Half-life decay

    func testHalfRemainingAtOneHalfLife() {
        let now = Date.now
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let entry = CaffeineEntry(date: fiveHoursAgo, milligrams: 200, source: "Pre-Workout")
        // 5h half-life → 200mg → 100mg after 5h
        XCTAssertCloseEnough(entry.remainingCaffeine(at: now, halfLifeHours: 5), 100)
    }

    func testQuarterRemainingAtTwoHalfLives() {
        let now = Date.now
        let tenHoursAgo = now.addingTimeInterval(-10 * 3600)
        let entry = CaffeineEntry(date: tenHoursAgo, milligrams: 200, source: "Pre-Workout")
        // 5h half-life → 200mg → 100mg → 50mg after 10h
        XCTAssertCloseEnough(entry.remainingCaffeine(at: now, halfLifeHours: 5), 50)
    }

    // MARK: - Sensitivity profiles

    func testFastMetabolizerHasFasterDecay() {
        let now = Date.now
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let entry = CaffeineEntry(date: fiveHoursAgo, milligrams: 200, source: "Coffee")
        // Fast (3h) → roughly 200 * 0.5^(5/3) ≈ 63 mg
        let remaining = entry.remainingCaffeine(at: now, halfLifeHours: 3)
        XCTAssertLessThan(remaining, 75)
        XCTAssertGreaterThan(remaining, 55)
    }

    func testSlowMetabolizerHasSlowerDecay() {
        let now = Date.now
        let fiveHoursAgo = now.addingTimeInterval(-5 * 3600)
        let entry = CaffeineEntry(date: fiveHoursAgo, milligrams: 200, source: "Coffee")
        // Slow (7h) → roughly 200 * 0.5^(5/7) ≈ 122 mg
        let remaining = entry.remainingCaffeine(at: now, halfLifeHours: 7)
        XCTAssertGreaterThan(remaining, 110)
        XCTAssertLessThan(remaining, 135)
    }

    // MARK: - Edge cases

    func testFutureTimeBeforeConsumptionReturnsZero() {
        // Asking for caffeine "before" the entry was logged
        let now = Date.now
        let entry = CaffeineEntry(date: now, milligrams: 100, source: "Coffee")
        let oneHourEarlier = now.addingTimeInterval(-3600)
        XCTAssertEqual(entry.remainingCaffeine(at: oneHourEarlier), 0)
    }

    func testDecayContinuesIndefinitely() {
        // After 24 hours (~5 half-lives at 5h) very little caffeine remains
        let now = Date.now
        let dayAgo = now.addingTimeInterval(-24 * 3600)
        let entry = CaffeineEntry(date: dayAgo, milligrams: 200, source: "Coffee")
        let remaining = entry.remainingCaffeine(at: now, halfLifeHours: 5)
        XCTAssertLessThan(remaining, 10)   // Practically gone
        XCTAssertGreaterThan(remaining, 0) // But never reaches exactly zero
    }

    func testZeroMilligramEntry() {
        let entry = CaffeineEntry(date: .now, milligrams: 0, source: "Decaf")
        XCTAssertEqual(entry.remainingCaffeine(at: .now), 0)
        XCTAssertEqual(entry.remainingCaffeine(at: Date.now.addingTimeInterval(3600)), 0)
    }

    // MARK: - Sensitivity enum

    func testSensitivityHalfLifeMatchesDescription() {
        XCTAssertEqual(CaffeineEntry.Sensitivity.slow.halfLifeHours, 7.0)
        XCTAssertEqual(CaffeineEntry.Sensitivity.normal.halfLifeHours, 5.0)
        XCTAssertEqual(CaffeineEntry.Sensitivity.fast.halfLifeHours, 3.0)
    }
}
