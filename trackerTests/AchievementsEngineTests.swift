import XCTest
import HealthKit
@testable import tracker

@MainActor
final class AchievementsEngineTests: XCTestCase {

    private func inputs(
        finished: [Workout] = [],
        all: [Workout] = [],
        cardio: [CardioSession] = [],
        bodyWeights: [BodyWeightEntry] = [],
        steps: [(date: Date, steps: Double)] = [],
        sleep: [(date: Date, minutes: Double)] = [],
        external: [ExternalWorkout] = []
    ) -> AchievementsEngine.Inputs {
        AchievementsEngine.Inputs(
            finishedWorkouts: finished,
            allWorkouts: all,
            cardioSessions: cardio,
            bodyWeights: bodyWeights,
            stepsData: steps,
            sleepData: sleep,
            externalWorkouts: external
        )
    }

    private func workout(weight: Double = 80, exercise: String = "Bench") -> Workout {
        let w = Workout(name: "Push", date: .now)
        let ex = Exercise(name: exercise, workout: w, category: .chest)
        ex.sets.append(ExerciseSet(reps: 8, weight: weight, exercise: ex))
        w.exercises.append(ex)
        return w
    }

    private func find(_ id: String, _ list: [Achievement]) -> Achievement? {
        list.first { $0.id == id }
    }

    func testEmptyInputsLockEverything() {
        let a = AchievementsEngine.allAchievements(from: inputs())
        XCTAssertFalse(a.isEmpty)
        XCTAssertFalse(a.contains { $0.isUnlocked })
        XCTAssertEqual(find("first_workout", a)?.progress, 0)
    }

    func testWorkoutCountUnlocksThresholds() {
        let workouts = (0..<10).map { _ in workout() }
        let a = AchievementsEngine.allAchievements(from: inputs(finished: workouts))
        XCTAssertEqual(find("first_workout", a)?.isUnlocked, true)
        XCTAssertEqual(find("ten_workouts", a)?.isUnlocked, true)
        XCTAssertEqual(find("25_workouts", a)?.isUnlocked, false)
        XCTAssertEqual(find("25_workouts", a)?.progress ?? -1, 0.4, accuracy: 0.001) // 10/25
    }

    func testHeavyLiftUnlocksWeightAchievement() {
        let a = AchievementsEngine.allAchievements(from: inputs(finished: [workout(weight: 100)]))
        XCTAssertEqual(find("lift_100kg", a)?.isUnlocked, true)
        XCTAssertEqual(find("lift_140kg", a)?.isUnlocked, false)
    }

    func testVarietyCountsUniqueExercises() {
        let workouts = (0..<10).map { workout(exercise: "Lift \($0)") }
        let a = AchievementsEngine.allAchievements(from: inputs(finished: workouts))
        XCTAssertEqual(find("variety_10", a)?.isUnlocked, true)
        XCTAssertEqual(find("variety_25", a)?.isUnlocked, false)
    }

    func testStepStreakCountsConsecutive10kDaysAndBreaks() {
        let cal = Calendar.current
        var steps: [(date: Date, steps: Double)] = (0..<7).map {
            (cal.date(byAdding: .day, value: -$0, to: .now)!, 12_000)
        }
        var a = AchievementsEngine.allAchievements(from: inputs(steps: steps))
        XCTAssertEqual(find("step_streak_7", a)?.isUnlocked, true)

        steps[3] = (steps[3].date, 4_000) // a sub-goal day breaks the streak
        a = AchievementsEngine.allAchievements(from: inputs(steps: steps))
        XCTAssertEqual(find("step_streak_7", a)?.isUnlocked, false)
    }

    func testSleepStreakBreaksOnShortNight() {
        let cal = Calendar.current
        var sleep: [(date: Date, minutes: Double)] = (0..<5).map {
            (cal.date(byAdding: .day, value: -$0, to: .now)!, 7.5 * 60)
        }
        var a = AchievementsEngine.allAchievements(from: inputs(sleep: sleep))
        XCTAssertEqual(find("sleep_streak_5", a)?.isUnlocked, true)

        sleep[2] = (sleep[2].date, 5 * 60)
        a = AchievementsEngine.allAchievements(from: inputs(sleep: sleep))
        XCTAssertEqual(find("sleep_streak_5", a)?.isUnlocked, false)
    }

    func testRunningDistanceFromExternalWorkouts() {
        let run = ExternalWorkout(
            id: UUID(), workoutType: .running, startDate: .now, endDate: .now,
            duration: 1800, totalCalories: nil, totalDistance: 12_000, sourceName: "Strava"
        )
        let a = AchievementsEngine.allAchievements(from: inputs(external: [run]))
        XCTAssertEqual(find("first_run", a)?.isUnlocked, true)
        XCTAssertEqual(find("distance_10k", a)?.isUnlocked, true) // 12 km total
        XCTAssertEqual(find("single_10k", a)?.isUnlocked, true)   // 12 km single run
        XCTAssertEqual(find("single_half", a)?.isUnlocked, false) // < 21.1 km
    }
}
