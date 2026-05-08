//
//  TodayPlanEngineTests.swift
//  trackerTests
//
//  To run these tests, add a Unit Testing Bundle target to the Xcode project:
//    File → New → Target → Unit Testing Bundle, name it "trackerTests".
//    Make sure the host application is set to "tracker" so it can see internal types.
//

import XCTest
@testable import tracker

final class TodayPlanEngineTests: XCTestCase {

    // MARK: - Intensity selection

    func testRestIntensityWhenReadinessIsVeryLow() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 0.20),
            health: HealthSignals(),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .rest)
        XCTAssertEqual(plan.recommendedName, "Rest day")
        XCTAssertTrue(plan.adjustments.contains(where: { $0.contains("rest day") || $0.contains("gentle movement") }))
    }

    func testLightIntensityWhenReadinessIsBelowMidrange() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Pull Day",
            recovery: makeRecovery(score: 0.45),
            health: HealthSignals(),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .light)
        XCTAssertEqual(plan.recommendedName, "Pull Day", "Should preserve scheduled name on a light day")
        XCTAssertTrue(plan.adjustments.contains { $0.contains("Reduce volume") })
    }

    func testModerateIntensityInTheMiddleZone() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Legs",
            recovery: makeRecovery(score: 0.65),
            health: HealthSignals(),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .moderate)
        XCTAssertEqual(plan.recommendedName, "Legs")
    }

    func testHardIntensityWhenWellRecovered() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 0.90),
            health: HealthSignals(todayHRV: 60, averageHRV: 55),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .hard)
    }

    // MARK: - Already-trained shortcut

    func testAlreadyTrainedShortCircuits() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 0.30),  // would normally suggest rest
            health: HealthSignals(),
            alreadyTrainedToday: true
        )
        XCTAssertTrue(plan.alreadyTrainedToday)
        XCTAssertTrue(plan.adjustments.isEmpty, "No adjustments needed once trained")
        XCTAssertTrue(plan.reasons.contains { $0.contains("already trained") })
    }

    // MARK: - Confidence

    func testConfidenceLowWithNoSignals() {
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.confidence, .low)
    }

    func testConfidenceMediumWithOneSignal() {
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(todayHRV: 55),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.confidence, .medium)
    }

    func testConfidenceHighWithMultipleSignals() {
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(
                todayHRV: 55,
                averageHRV: 55,
                todayRestingHR: 60,
                averageRestingHR: 60,
                sleepMinutes: 480
            ),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.confidence, .high)
    }

    // MARK: - Recommended name fallback

    func testFallsBackToSuggestedTypeWhenNothingScheduled() {
        let recovery = makeRecovery(score: 0.65, suggestedType: "Pull Day")
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: recovery,
            health: HealthSignals(),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.recommendedName, "Pull Day")
    }

    func testEmptyStringScheduleIsIgnored() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "   ",
            recovery: makeRecovery(score: 0.65, suggestedType: "Full Body"),
            health: HealthSignals(),
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.recommendedName, "Full Body")
        XCTAssertNil(plan.scheduledName, "Whitespace-only schedule should normalize to nil")
    }

    // MARK: - Health-signal reasons

    func testShortSleepAddsReason() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 0.65),
            health: HealthSignals(sleepMinutes: 5 * 60),  // 5h
            alreadyTrainedToday: false
        )
        XCTAssertTrue(plan.reasons.contains { $0.contains("Sleep was short") })
    }

    func testHRVBelowBaselineAddsReason() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 0.65),
            health: HealthSignals(todayHRV: 40, averageHRV: 55),
            alreadyTrainedToday: false
        )
        XCTAssertTrue(plan.reasons.contains { $0.contains("HRV") && $0.contains("below") })
    }

    // MARK: - Reason cap

    func testReasonsAreCappedAtThree() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 0.20),  // adds a reason
            health: HealthSignals(
                todayHRV: 30, averageHRV: 55,
                todayRestingHR: 70, averageRestingHR: 60,
                sleepMinutes: 4 * 60
            ),
            alreadyTrainedToday: false
        )
        XCTAssertLessThanOrEqual(plan.reasons.count, 3)
    }

    // MARK: - Helpers

    private func makeRecovery(score: Double, suggestedType: String = "Anything") -> RecoveryResult {
        RecoveryResult(
            readinessScore: score,
            muscleResults: [],
            suggestedWorkoutType: suggestedType
        )
    }
}
