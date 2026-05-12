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

    // MARK: - Brand-new user

    func testFreshUserShowsFirstWorkoutMessage() {
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 1.0),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            hasAnyHistory: false
        )
        XCTAssertEqual(plan.recommendedName, "Your first workout")
        XCTAssertEqual(plan.confidence, .low)
        XCTAssertTrue(plan.reasons.contains { $0.contains("first workout") })
    }

    func testFreshUserWithScheduledPlanUsesScheduledName() {
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push Day",
            recovery: makeRecovery(score: 1.0),
            health: HealthSignals(),
            alreadyTrainedToday: false,
            hasAnyHistory: false
        )
        XCTAssertEqual(plan.recommendedName, "Push Day")
        // Even with a scheduled plan, no history means no recovery-based reasoning
        XCTAssertTrue(plan.reasons.contains { $0.contains("logged a few sessions") })
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
        // .high now requires BOTH 2+ health signals AND 7+ recent workouts
        // — a user with perfect HRV/sleep but no logged training should not
        // get high-confidence recommendations, the engine has no idea what
        // their normal looks like yet.
        let workouts = (1...8).map { makeWorkout(daysAgo: $0, chestExerciseCount: 1) }
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
            recentWorkouts: workouts,
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.confidence, .high)
    }

    func testConfidenceCappedAtMediumWhenHealthHighButNoWorkouts() {
        // Perfect HealthKit data, zero logged workouts → .medium, not .high.
        // Recovery engine can recommend rest/light based on health alone,
        // but it can't claim high confidence in a strength recommendation
        // when it's never seen the user lift.
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
            recentWorkouts: [],
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.confidence, .medium)
    }

    func testConfidenceCappedAtMediumWhenWorkoutsHighButNoHealth() {
        // Symmetric: lots of workout history, no health signals → .medium.
        // Engine can pattern-match training trends but can't see recovery.
        let workouts = (1...10).map { makeWorkout(daysAgo: $0, chestExerciseCount: 1) }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.75),
            health: HealthSignals(),
            recentWorkouts: workouts,
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.confidence, .medium)
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

    // MARK: - goEasy / avoid / adjustments

    func testFatiguedMusclesShowUpInGoEasyAndAdjustments() {
        // A muscle freshness below 0.4 should surface in goEasyOnGroups and
        // produce a "Go easy on …" adjustment string.
        let recovery = RecoveryResult(
            readinessScore: 0.7,
            muscleResults: [
                MuscleFatigueResult(group: .chest, freshness: 0.2,
                                    lastTrained: nil, effectiveRecoveryHours: 48),
                MuscleFatigueResult(group: .legs, freshness: 0.9,
                                    lastTrained: nil, effectiveRecoveryHours: 48)
            ],
            suggestedWorkoutType: "Anything"
        )
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: recovery,
            health: HealthSignals(),
            recentWorkouts: [],
            alreadyTrainedToday: false
        )
        XCTAssertTrue(plan.goEasyOnGroups.contains(MuscleGroup.chest))
        XCTAssertFalse(plan.goEasyOnGroups.contains(MuscleGroup.legs))
        XCTAssertTrue(plan.adjustments.contains { $0.lowercased().contains("go easy") },
                      "Expected a 'go easy' adjustment to be added")
    }

    func testRestIntensityAdjustmentMatchesIntensity() {
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.2),
            health: HealthSignals(),
            recentWorkouts: [],
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .rest)
        XCTAssertTrue(plan.adjustments.contains { $0.lowercased().contains("rest day") })
    }

    func testLightIntensityAddsTwoVolumeAdjustments() {
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.45),
            health: HealthSignals(),
            recentWorkouts: [],
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .light)
        XCTAssertTrue(plan.adjustments.contains { $0.lowercased().contains("reduce volume") })
        XCTAssertTrue(plan.adjustments.contains { $0.lowercased().contains("short of failure") })
    }

    func testHardIntensityWithLowConfidenceSkipsTopSetSuggestion() {
        // With no health signals confidence is .low — engine should be
        // conservative and NOT suggest pushing for a top-end set.
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.9),
            health: HealthSignals(),
            recentWorkouts: [],
            alreadyTrainedToday: false
        )
        XCTAssertEqual(plan.intensity, .hard)
        XCTAssertEqual(plan.confidence, .low)
        XCTAssertFalse(plan.adjustments.contains { $0.lowercased().contains("top-end set") },
                       "Don't push a top-end set when confidence is low")
    }

    // MARK: - alreadyTrainedToday wins regardless of recovery

    func testAlreadyTrainedShortCircuitsEvenWithHorribleRecovery() {
        // Even with a 5% readiness score, having already trained should
        // produce the same "nice work" plan — the user's already done.
        let plan = TodayPlanEngine.generate(
            scheduledName: "Push",
            recovery: makeRecovery(score: 0.05),
            health: HealthSignals(),
            recentWorkouts: [],
            alreadyTrainedToday: true
        )
        XCTAssertTrue(plan.alreadyTrainedToday)
        XCTAssertNotEqual(plan.intensity, .rest, "Already-trained path shouldn't fall through to rest")
    }

    // MARK: - overworkedGroup counts days, not exercises

    func testSingleChestWorkoutDoesNotFlagAsOverworked() {
        // One push session with bench + incline + fly should NOT trigger
        // the "you've hit chest several times this week" adjustment —
        // before this fix, it counted as 3 chest entries.
        let workout = makeWorkout(daysAgo: 1, chestExerciseCount: 3)
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.7),
            health: HealthSignals(),
            recentWorkouts: [workout],
            alreadyTrainedToday: false
        )
        XCTAssertFalse(plan.avoidGroups.contains(.chest),
                       "A single chest workout shouldn't be flagged as overworked")
        XCTAssertFalse(plan.adjustments.contains { $0.lowercased().contains("hit chest") },
                       "No 'hit chest several times' adjustment from one session")
    }

    func testThreeChestDaysInFiveFlagsAsOverworked() {
        // Three distinct days that each include chest in the last 5 days
        // should trigger the overworked flag.
        let workouts = (1...3).map { makeWorkout(daysAgo: $0, chestExerciseCount: 1) }
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: makeRecovery(score: 0.7),
            health: HealthSignals(),
            recentWorkouts: workouts,
            alreadyTrainedToday: false
        )
        XCTAssertTrue(plan.avoidGroups.contains(.chest))
    }

    private func makeWorkout(daysAgo: Int, chestExerciseCount: Int) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let workout = Workout(name: "Push", date: date)
        workout.endTime = date.addingTimeInterval(3600)
        for i in 0..<chestExerciseCount {
            let ex = Exercise(name: "Bench \(i)", workout: workout, category: .chest)
            ex.sets.append(ExerciseSet(reps: 8, weight: 80, exercise: ex))
            workout.exercises.append(ex)
        }
        return workout
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
