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

    func testGoodSleepNeverLowersScore() {
        // ≥7.5h boosts the score by ~5% (multiplier 1.05) per RecoveryEngine
        let workouts = [makeChestWorkout(daysAgo: 5)]
        let neutral  = HealthSignals()
        let boosted  = HealthSignals(sleepMinutes: 8 * 60)

        let neutralResult = RecoveryEngine.evaluate(workouts: workouts, health: neutral)
        let boostedResult = RecoveryEngine.evaluate(workouts: workouts, health: boosted)

        XCTAssertGreaterThanOrEqual(boostedResult.readinessScore, neutralResult.readinessScore)
        XCTAssertLessThanOrEqual(boostedResult.readinessScore, 1.0)
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
        XCTAssertEqual(result.readinessScore, 1.0, accuracy: 0.001,
                       "Stacked good signals + recovered muscles clamp to exactly 1.0")
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
        XCTAssertLessThan(result.readinessScore, 0.10,
                          "All three physiology signals floored should leave readiness near zero")
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

    func testCombinedNegativeSignalsStayLow() {
        // Physiology is a weighted blend of the available signals, so a second
        // bad signal never *improves* readiness: the combined score stays at or
        // below the less-severe of the two single-signal scores, and well below
        // baseline. (Inputs chosen so neither sub-score clamps to its floor,
        // which would make the comparison degenerate.)
        let baseline = RecoveryEngine.evaluate(workouts: [], health: HealthSignals())

        let shortSleepOnly = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(sleepMinutes: 300)   // 5h → ~0.33
        )
        let lowHRVOnly = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(todayHRV: 40, averageHRV: 50)   // 0.8× → ~0.40
        )
        let both = RecoveryEngine.evaluate(
            workouts: [],
            health: HealthSignals(
                todayHRV: 40, averageHRV: 50,
                sleepMinutes: 300
            )
        )

        XCTAssertLessThan(shortSleepOnly.readinessScore, baseline.readinessScore)
        XCTAssertLessThan(lowHRVOnly.readinessScore, baseline.readinessScore)
        XCTAssertLessThan(both.readinessScore, baseline.readinessScore)
        XCTAssertLessThanOrEqual(both.readinessScore,
                                 max(shortSleepOnly.readinessScore, lowHRVOnly.readinessScore),
                                 "Adding a second negative signal must not raise readiness above the less-severe one")
    }

    func testRoughNightReadsLow() {
        // The motivating case: muscles are fresh (no recent training) but the
        // user drank and slept badly. Suppressed HRV, short sleep, and an
        // elevated resting HR should land readiness in clearly-low territory,
        // not the ~80% the old muscle-first model produced.
        let roughNight = HealthSignals(
            todayHRV: 32, averageHRV: 50,            // −36% (typical post-alcohol)
            todayRestingHR: 66, averageRestingHR: 60, // +10%
            sleepMinutes: 5 * 60                       // 5h, poor
        )
        let result = RecoveryEngine.evaluate(workouts: [], health: roughNight)

        XCTAssertLessThan(result.readinessScore, 0.40,
                          "A wrecked night should read clearly low even with fresh muscles")
    }

    // MARK: - Physiology calibration

    private func score(_ health: HealthSignals) -> Double {
        RecoveryEngine.evaluate(workouts: [], health: health).readinessScore
    }

    func testBaselineDayReachesHardThreshold() {
        let baseline = HealthSignals(
            todayHRV: 50, averageHRV: 50,
            todayRestingHR: 60, averageRestingHR: 60,
            sleepMinutes: 7 * 60
        )
        let s = score(baseline)
        XCTAssertEqual(s, 1.0, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(s, EngineConstants.TodayPlan.hardThreshold)
    }

    func testSleepScoreClampsAndGradient() {
        XCTAssertEqual(score(HealthSignals(sleepMinutes: 9 * 60)), 1.0, accuracy: 0.001)
        XCTAssertEqual(score(HealthSignals(sleepMinutes: 7 * 60)), 1.0, accuracy: 0.001)
        // (6 - 3.5) / (7 - 3.5)
        XCTAssertEqual(score(HealthSignals(sleepMinutes: 6 * 60)), 2.5 / 3.5, accuracy: 0.001)
        // Sleep floor: at/below 3.5h the sleep sub-score is 0
        XCTAssertEqual(score(HealthSignals(sleepMinutes: 3.5 * 60)), 0.0, accuracy: 0.001)
        XCTAssertEqual(score(HealthSignals(sleepMinutes: 3.2 * 60)), 0.0, accuracy: 0.001)
    }

    func testTinySleepTreatedAsMissing() {
        // 2h (nap / partial sample) must behave exactly like no sleep data.
        XCTAssertEqual(score(HealthSignals(sleepMinutes: 120)), score(HealthSignals()), accuracy: 0.0001)
        XCTAssertNil(RecoveryEngine.validSleepHours(120))
        XCTAssertNil(RecoveryEngine.validSleepHours(nil))
        XCTAssertEqual(RecoveryEngine.validSleepHours(180) ?? 0, 3.0, accuracy: 0.0001)
    }

    func testHRVSlopeAndClamps() {
        XCTAssertEqual(score(HealthSignals(todayHRV: 42.5, averageHRV: 50)), 0.70, accuracy: 0.001) // -15%
        XCTAssertEqual(score(HealthSignals(todayHRV: 20, averageHRV: 50)), 0.0, accuracy: 0.001)    // clamp low
        XCTAssertEqual(score(HealthSignals(todayHRV: 90, averageHRV: 50)), 1.0, accuracy: 0.001)    // clamp high
    }

    func testRHRSlopeAndClamps() {
        XCTAssertEqual(score(HealthSignals(todayRestingHR: 63, averageRestingHR: 60)), 0.80, accuracy: 0.001) // +5%
        XCTAssertEqual(score(HealthSignals(todayRestingHR: 90, averageRestingHR: 60)), 0.0, accuracy: 0.001)
        XCTAssertEqual(score(HealthSignals(todayRestingHR: 50, averageRestingHR: 60)), 1.0, accuracy: 0.001)
    }

    func testPartialSignalsRenormaliseWeights() {
        // HRV only (-15% → 0.70): weight renormalised to 1, so score is 0.70, not 0.70 * 0.45.
        XCTAssertEqual(score(HealthSignals(todayHRV: 42.5, averageHRV: 50)), 0.70, accuracy: 0.001)
        // HRV 0.70 (w .45) + sleep 7h 1.0 (w .35) → (0.315 + 0.35) / 0.80
        let blended = score(HealthSignals(todayHRV: 42.5, averageHRV: 50, sleepMinutes: 7 * 60))
        XCTAssertEqual(blended, 0.665 / 0.80, accuracy: 0.001)
    }

    func testNoHealthFallsBackToMuscleFreshness() {
        let reports = trainableReports(level: 4)
        let result = RecoveryEngine.evaluate(workouts: [], sorenessReports: reports)
        XCTAssertEqual(result.readinessScore, 1.0 - 4 * EngineConstants.Recovery.sorenessLevelStep, accuracy: 0.001)
    }

    func testMuscleModulationIsGentleWithPhysiology() {
        let reports = trainableReports(level: 4)   // all muscles at 0.70 freshness
        let perfect = HealthSignals(sleepMinutes: 7 * 60)
        let result = RecoveryEngine.evaluate(workouts: [], health: perfect, sorenessReports: reports)
        let C = EngineConstants.Recovery.self
        let expected = C.muscleModulationFloor + (1 - C.muscleModulationFloor) * 0.70
        XCTAssertEqual(result.readinessScore, expected, accuracy: 0.001)
        // Never below physiology * floor
        XCTAssertGreaterThanOrEqual(result.readinessScore, C.muscleModulationFloor)
    }

    func testHealthSignalsNotDoubleCountedInAggregate() {
        // Poor HRV slows per-muscle recovery hours but the aggregate for a
        // recently-trained user must equal physiology * modulation computed
        // from neutral muscle freshness.
        let workouts = [makeChestWorkout(daysAgo: 1, sets: 4)]
        let hrv = HealthSignals(todayHRV: 40, averageHRV: 50)    // ratio 0.80 (< hrvLowRatio), physiology 0.60
        let neutral = RecoveryEngine.evaluate(workouts: workouts)
        let withHRV = RecoveryEngine.evaluate(workouts: workouts, health: hrv)
        let C = EngineConstants.Recovery.self
        let neutralMean = neutral.muscleResults.map(\.freshness).reduce(0, +) / Double(neutral.muscleResults.count)
        let expected = 0.60 * (C.muscleModulationFloor + (1 - C.muscleModulationFloor) * neutralMean)
        XCTAssertEqual(withHRV.readinessScore, expected, accuracy: 0.001)
        // Per-muscle display still reflects the slower recovery.
        let chestNeutral = neutral.muscleResults.first { $0.group == .chest }!
        let chestHRV = withHRV.muscleResults.first { $0.group == .chest }!
        XCTAssertGreaterThan(chestHRV.effectiveRecoveryHours, chestNeutral.effectiveRecoveryHours)
    }

    func testReadinessMonotonicInHRV() {
        let ratios: [Double] = [0.5, 0.7, 0.85, 0.95, 1.0]
        let scores = ratios.map { score(HealthSignals(todayHRV: 50 * $0, averageHRV: 50)) }
        for i in 1..<scores.count { XCTAssertGreaterThanOrEqual(scores[i], scores[i - 1]) }
        XCTAssertLessThan(scores.first!, scores.last!)
    }

    func testEmptyResultUsesUnknownReadiness() {
        XCTAssertEqual(RecoveryResult.empty.readinessScore, EngineConstants.Recovery.unknownReadiness)
    }

    func testUnsortedWorkoutsStillCountRecentSessions() {
        // Oldest-first input must not terminate the scan early.
        let workouts = [makeChestWorkout(daysAgo: 30), makeChestWorkout(daysAgo: 0, sets: 5)]
        let result = RecoveryEngine.evaluate(workouts: workouts)
        let chest = result.muscleResults.first { $0.group == .chest }!
        XCTAssertLessThan(chest.freshness, 1.0)
        XCTAssertNotNil(chest.lastTrained)
    }

    // MARK: - Helpers

    private func trainableReports(level: Int) -> [SorenessEntry] {
        RecoveryEngine.trainableGroups.map { SorenessEntry(date: .now, group: $0, level: level) }
    }

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
