import XCTest
import HealthKit
@testable import tracker

final class RecoveryEngineTests: XCTestCase {

    // MARK: - Empty inputs

    func testEmptyEverythingReturnsHighScore() {
        // With no recent training and no health signals, the user is fully
        // recovered — the average freshness across all groups is 1.0.
        let result = RecoveryEngine.evaluate(workouts: [])
        XCTAssertEqual(result.readinessScore, 1.0, accuracy: 0.01)
    }

    func testEmptyInputProducesAllMusclesAtFullFreshness() {
        // The engine always emits one result per trainable group; with no
        // recent training, every group should be at 100% freshness.
        let result = RecoveryEngine.evaluate(workouts: [])
        XCTAssertFalse(result.muscleResults.isEmpty)
        for r in result.muscleResults {
            XCTAssertEqual(r.freshness, 1.0, accuracy: 0.001)
            XCTAssertNil(r.lastTrained)
        }
    }

    // MARK: - Sleep modifier

    func testShortSleepReducesScore() {
        let workouts = [makeChestWorkout(daysAgo: 5)]   // mostly recovered
        let goodSleep = HealthSignals(sleepMinutes: 8 * 60)
        let badSleep  = HealthSignals(sleepMinutes: 5 * 60)

        let withGood = RecoveryEngine.evaluate(workouts: workouts, health: goodSleep)
        let withBad  = RecoveryEngine.evaluate(workouts: workouts, health: badSleep)

        XCTAssertGreaterThan(withGood.readinessScore, withBad.readinessScore,
                             "Good sleep should produce a higher readiness score than poor sleep")
    }

    func testSleepBoostMatchesEnginePolicy() {
        // ≥7.5h boosts the score by ~5% (multiplier 1.05) per RecoveryEngine
        let workouts = [makeChestWorkout(daysAgo: 5)]
        let neutral  = HealthSignals()
        let boosted  = HealthSignals(sleepMinutes: 8 * 60)

        let neutralResult = RecoveryEngine.evaluate(workouts: workouts, health: neutral)
        let boostedResult = RecoveryEngine.evaluate(workouts: workouts, health: boosted)

        XCTAssertGreaterThanOrEqual(boostedResult.readinessScore, neutralResult.readinessScore)
    }

    // MARK: - HRV modifier

    func testHRVBelowBaselineReducesScore() {
        let workouts = [makeChestWorkout(daysAgo: 5)]
        let lowHRV  = HealthSignals(todayHRV: 35, averageHRV: 50)
        let highHRV = HealthSignals(todayHRV: 60, averageHRV: 50)

        let withLow  = RecoveryEngine.evaluate(workouts: workouts, health: lowHRV)
        let withHigh = RecoveryEngine.evaluate(workouts: workouts, health: highHRV)

        XCTAssertLessThan(withLow.readinessScore, withHigh.readinessScore)
    }

    // MARK: - Resting HR modifier

    func testElevatedRestingHRReducesScore() {
        let workouts = [makeChestWorkout(daysAgo: 5)]
        let normalRHR   = HealthSignals(todayRestingHR: 60, averageRestingHR: 60)
        let elevatedRHR = HealthSignals(todayRestingHR: 70, averageRestingHR: 60) // +17%

        let normal   = RecoveryEngine.evaluate(workouts: workouts, health: normalRHR)
        let elevated = RecoveryEngine.evaluate(workouts: workouts, health: elevatedRHR)

        XCTAssertLessThan(elevated.readinessScore, normal.readinessScore)
    }

    // MARK: - Score bounds

    func testScoreNeverExceedsOne() {
        let workouts = [makeChestWorkout(daysAgo: 30)]
        let stackedGoodSignals = HealthSignals(
            todayHRV: 100, averageHRV: 50,           // way above baseline
            todayRestingHR: 50, averageRestingHR: 60, // below baseline
            sleepMinutes: 9 * 60                      // long sleep
        )
        let result = RecoveryEngine.evaluate(workouts: workouts, health: stackedGoodSignals)
        XCTAssertLessThanOrEqual(result.readinessScore, 1.0)
    }

    func testScoreNeverDropsBelowZero() {
        // Heavy back-to-back chest sessions plus terrible health signals
        let workouts = (0...3).map { makeChestWorkout(daysAgo: $0, sets: 6) }
        let bad = HealthSignals(
            todayHRV: 20, averageHRV: 60,
            todayRestingHR: 90, averageRestingHR: 60,
            sleepMinutes: 4 * 60
        )
        let result = RecoveryEngine.evaluate(workouts: workouts, health: bad)
        XCTAssertGreaterThanOrEqual(result.readinessScore, 0.0)
    }

    // MARK: - Suggested workout type

    func testSuggestsRestWhenAllMusclesFatigued() {
        let fatiguedResults: [MuscleFatigueResult] = MuscleGroup.allCases
            .filter { $0 != .cardio && $0 != .other }
            .map {
                MuscleFatigueResult(group: $0, freshness: 0.3,
                                    lastTrained: .now, effectiveRecoveryHours: 48)
            }
        let suggestion = RecoveryEngine.suggestWorkoutType(from: fatiguedResults)
        XCTAssertEqual(suggestion, "Recovery")
    }

    func testSuggestsPushWhenChestShouldersTricepsReady() {
        let results: [MuscleFatigueResult] = [
            .init(group: .chest,     freshness: 0.9, lastTrained: nil, effectiveRecoveryHours: 48),
            .init(group: .shoulders, freshness: 0.9, lastTrained: nil, effectiveRecoveryHours: 48),
            .init(group: .triceps,   freshness: 0.9, lastTrained: nil, effectiveRecoveryHours: 36),
            .init(group: .back,      freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 48),
            .init(group: .biceps,    freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 36),
            .init(group: .legs,      freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 72),
        ]
        XCTAssertEqual(RecoveryEngine.suggestWorkoutType(from: results), "Push Day")
    }

    func testSuggestsPullWhenBackBicepsReady() {
        let results: [MuscleFatigueResult] = [
            .init(group: .chest,     freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 48),
            .init(group: .back,      freshness: 0.9, lastTrained: nil, effectiveRecoveryHours: 48),
            .init(group: .biceps,    freshness: 0.9, lastTrained: nil, effectiveRecoveryHours: 36),
            .init(group: .triceps,   freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 36),
            .init(group: .shoulders, freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 48),
            .init(group: .legs,      freshness: 0.4, lastTrained: nil, effectiveRecoveryHours: 72),
        ]
        XCTAssertEqual(RecoveryEngine.suggestWorkoutType(from: results), "Pull Day")
    }

    // MARK: - Display helpers

    func testReadinessLabelTransitions() {
        XCTAssertTrue(RecoveryEngine.readinessLabel(0.9).contains("recovered"))
        XCTAssertTrue(RecoveryEngine.readinessLabel(0.6).contains("recovered"))
        XCTAssertTrue(RecoveryEngine.readinessLabel(0.3).contains("recovering"))
        XCTAssertTrue(RecoveryEngine.readinessLabel(0.1).contains("rest"))
    }

    func testFreshnessLabelTransitions() {
        XCTAssertEqual(RecoveryEngine.freshnessLabel(0.9), "Ready")
        XCTAssertEqual(RecoveryEngine.freshnessLabel(0.6), "Almost")
        XCTAssertEqual(RecoveryEngine.freshnessLabel(0.3), "Recovering")
        XCTAssertEqual(RecoveryEngine.freshnessLabel(0.1), "Fatigued")
    }

    // MARK: - Time decay

    func testRecentWorkoutFatiguesMoreThanOlderWorkout() {
        // Same exact workout, two different recencies. The 1-day-ago version
        // should leave less freshness than the 6-day-ago version.
        let chest1d = makeChestWorkout(daysAgo: 1)
        let chest6d = makeChestWorkout(daysAgo: 6)

        let resultRecent = RecoveryEngine.evaluate(
            workouts: [chest1d],
            health: HealthSignals(),
            externalWorkouts: [],
            cardioSessions: []
        )
        let resultOlder = RecoveryEngine.evaluate(
            workouts: [chest6d],
            health: HealthSignals(),
            externalWorkouts: [],
            cardioSessions: []
        )

        let recentChest = resultRecent.muscleResults.first { $0.group == .chest }?.freshness ?? 0
        let olderChest = resultOlder.muscleResults.first { $0.group == .chest }?.freshness ?? 0
        XCTAssertLessThan(recentChest, olderChest,
                          "A 1-day-ago workout should leave the muscle less fresh than a 6-day-ago one")
    }

    // MARK: - External workouts

    func testExternalRunReducesLegsFreshness() {
        // Sanity: a HealthKit-sourced run that wasn't logged in this app should
        // still pull leg freshness down.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let run = ExternalWorkout(
            id: UUID(),
            workoutType: .running,
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(40 * 60),
            duration: 40 * 60,
            totalCalories: 350,
            totalDistance: 7_000,
            sourceName: "Apple Watch"
        )
        let baseline = RecoveryEngine.evaluate(workouts: [], health: HealthSignals())
        let withRun = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(),
            externalWorkouts: [run]
        )
        let baseLegs = baseline.muscleResults.first { $0.group == .legs }?.freshness ?? 1.0
        let runLegs = withRun.muscleResults.first { $0.group == .legs }?.freshness ?? 1.0
        XCTAssertLessThan(runLegs, baseLegs, "External run should reduce leg freshness")
    }

    func testExternalAppSourcedWorkoutIsIgnored() {
        // Workouts that came FROM this app shouldn't be double-counted as
        // external — RecoveryEngine already sees them via the local store.
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let selfReport = ExternalWorkout(
            id: UUID(),
            workoutType: .running,
            startDate: yesterday,
            endDate: yesterday.addingTimeInterval(30 * 60),
            duration: 30 * 60,
            totalCalories: 300,
            totalDistance: 5_000,
            sourceName: "Metricly"
        )
        let baseline = RecoveryEngine.evaluate(workouts: [], health: HealthSignals())
        let withSelf = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(),
            externalWorkouts: [selfReport]
        )
        let baseLegs = baseline.muscleResults.first { $0.group == .legs }?.freshness ?? 1.0
        let selfLegs = withSelf.muscleResults.first { $0.group == .legs }?.freshness ?? 1.0
        XCTAssertEqual(baseLegs, selfLegs, accuracy: 0.001,
                       "App-sourced external workouts should not be applied (avoid double-counting)")
    }

    // MARK: - Cardio sessions

    func testCardioSessionReducesLegsFreshness() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let run = CardioSession(date: yesterday,
                                title: "5k easy",
                                type: .outdoorRun,
                                durationSeconds: 30 * 60,
                                distanceMeters: 5_000)
        let baseline = RecoveryEngine.evaluate(workouts: [], health: HealthSignals())
        let withRun = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(),
            cardioSessions: [run]
        )
        let baseLegs = baseline.muscleResults.first { $0.group == .legs }?.freshness ?? 1.0
        let runLegs = withRun.muscleResults.first { $0.group == .legs }?.freshness ?? 1.0
        XCTAssertLessThan(runLegs, baseLegs)
    }

    // MARK: - Combined health signals

    func testCombinedNegativeSignalsCompound() {
        // Two bad signals at once should produce a lower score than either
        // alone. Catches the case where the engine accidentally treats
        // them as substitutes rather than additive.
        let baseline = RecoveryEngine.evaluate(workouts: [], health: HealthSignals())

        let shortSleepOnly = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(sleepMinutes: 240)
        )
        let lowHRVOnly = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(todayHRV: 20, averageHRV: 50)
        )
        let both = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(
                todayHRV: 20, averageHRV: 50,
                sleepMinutes: 240
            )
        )

        XCTAssertLessThan(shortSleepOnly.readinessScore, baseline.readinessScore)
        XCTAssertLessThan(lowHRVOnly.readinessScore, baseline.readinessScore)
        XCTAssertLessThanOrEqual(both.readinessScore,
                                 min(shortSleepOnly.readinessScore, lowHRVOnly.readinessScore),
                                 "Stacking two negative signals shouldn't be more lenient than either alone")
    }

    // MARK: - Helpers

    private func makeChestWorkout(daysAgo: Int, sets: Int = 3) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let w = Workout(name: "Push", date: date)
        w.endTime = date.addingTimeInterval(3600)

        let ex = Exercise(name: "Bench Press", workout: w, category: .chest)
        for _ in 0..<sets {
            let s = ExerciseSet(reps: 8, weight: 80, exercise: ex)
            ex.sets.append(s)
        }
        w.exercises.append(ex)
        return w
    }
}
