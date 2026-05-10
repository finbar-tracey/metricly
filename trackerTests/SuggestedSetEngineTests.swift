import XCTest
@testable import tracker

final class SuggestedSetEngineTests: XCTestCase {

    // MARK: - No history

    func testNilWhenExerciseHasNoHistoryAndNoSets() {
        let exercise = makeExercise(name: "Bench")
        let result = SuggestedSetEngine.suggestNextSet(for: exercise, history: [])
        XCTAssertNil(result)
    }

    // MARK: - Within-session

    func testRepeatsLastInSessionSet() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80)
        let result = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.reps, 8)
        XCTAssertEqual(result?.weight, 80)
        XCTAssertEqual(result?.source, .repeatInSession)
        XCTAssertEqual(result?.label, "Repeat last")
    }

    func testInSessionPrefersWorkingSetOverWarmUp() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 12, weight: 40, isWarmUp: true)
        addSet(to: exercise, reps: 8, weight: 80)
        let result = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        // Should mirror the working set, not the warm-up
        XCTAssertEqual(result?.reps, 8)
        XCTAssertEqual(result?.weight, 80)
    }

    // MARK: - Progression: increase

    func testIncreasesWeightAfterLowRPESessions() {
        // Two prior sessions both at RPE 7 → ProgressionAdvisor recommends increase
        let prev1 = makeHistoricalExercise(name: "Bench", daysAgo: 7,  reps: 8, weight: 80, rpe: 7)
        let prev2 = makeHistoricalExercise(name: "Bench", daysAgo: 14, reps: 8, weight: 80, rpe: 7)
        let current = makeExercise(name: "Bench")   // empty — first set today

        let result = SuggestedSetEngine.suggestNextSet(
            for: current,
            history: [current, prev1, prev2]
        )

        XCTAssertEqual(result?.source, .progression)
        XCTAssertEqual(result?.label, "Add weight")
        XCTAssertEqual(result?.weight ?? 0, 82.5, accuracy: 0.01,
                       "Chest increment is 2.5 kg → 80 + 2.5 = 82.5")
        XCTAssertEqual(result?.reps, 8, "Same reps as last session")
    }

    func testLegsUseLargerIncrement() {
        let prev1 = makeHistoricalExercise(name: "Squat", daysAgo: 7,  reps: 5, weight: 140, rpe: 7, category: .legs)
        let prev2 = makeHistoricalExercise(name: "Squat", daysAgo: 14, reps: 5, weight: 140, rpe: 7, category: .legs)
        let current = makeExercise(name: "Squat", category: .legs)

        let result = SuggestedSetEngine.suggestNextSet(
            for: current,
            history: [current, prev1, prev2]
        )
        XCTAssertEqual(result?.weight ?? 0, 145.0, accuracy: 0.01, "Legs add 5 kg")
    }

    // MARK: - Progression: hold (add a rep)

    func testAddsARepWhenAdvisorSaysHold() {
        // RPE 8 average → hold; engine adds a rep at the same weight
        let prev1 = makeHistoricalExercise(name: "Bench", daysAgo: 7,  reps: 5, weight: 100, rpe: 9)
        let prev2 = makeHistoricalExercise(name: "Bench", daysAgo: 14, reps: 5, weight: 100, rpe: 8)
        let current = makeExercise(name: "Bench")

        let result = SuggestedSetEngine.suggestNextSet(
            for: current,
            history: [current, prev1, prev2]
        )
        XCTAssertEqual(result?.label, "Add a rep")
        XCTAssertEqual(result?.reps, 6, "Last reps + 1")
        XCTAssertEqual(result?.weight, 100, "Same weight as last session")
    }

    // MARK: - Progression: deload

    func testDeloadsAfterHighRPESessions() {
        let prev1 = makeHistoricalExercise(name: "Bench", daysAgo: 7,  reps: 5, weight: 110, rpe: 10)
        let prev2 = makeHistoricalExercise(name: "Bench", daysAgo: 14, reps: 5, weight: 110, rpe: 9)
        let current = makeExercise(name: "Bench")

        let result = SuggestedSetEngine.suggestNextSet(
            for: current,
            history: [current, prev1, prev2]
        )
        XCTAssertEqual(result?.source, .deload)
        XCTAssertEqual(result?.label, "Deload")
        // Chest increment is 2.5, so deload reduces by 2.5: 110 → 107.5
        XCTAssertEqual(result?.weight ?? 0, 107.5, accuracy: 0.01)
    }

    // MARK: - Repeat-last fallback

    func testRepeatsLastWhenNoRPEAndOnlyOneSession() {
        // Only one prior session — Advisor says insufficient → engine falls
        // back to repeating the last working set
        let prev = makeHistoricalExercise(name: "Bench", daysAgo: 7, reps: 8, weight: 80)
        let current = makeExercise(name: "Bench")

        let result = SuggestedSetEngine.suggestNextSet(
            for: current,
            history: [current, prev]
        )
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.weight, 80)
        XCTAssertEqual(result?.reps, 8)
        XCTAssertEqual(result?.source, .repeatInSession,
                       "Falls back to repeat-last when no progression signal")
    }

    // MARK: - Excludes templates

    func testIgnoresTemplateWorkouts() {
        let template = Workout(name: "Push Template", isTemplate: true)
        let templateExercise = Exercise(name: "Bench", workout: template, category: .chest)
        templateExercise.sets.append(ExerciseSet(reps: 8, weight: 999, exercise: templateExercise))
        template.exercises.append(templateExercise)

        let current = makeExercise(name: "Bench")
        let result = SuggestedSetEngine.suggestNextSet(
            for: current,
            history: [current, templateExercise]
        )
        // Template values should not bleed into the suggestion
        XCTAssertNotEqual(result?.weight, 999)
        XCTAssertNil(result, "No real history available")
    }

    // MARK: - Within-session RPE coaching

    func testRpeLowSinglePushesARep() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 6)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.reps, 9, "Single low-RPE set should push +1 rep, not weight")
        XCTAssertEqual(r?.weight, 80)
        XCTAssertEqual(r?.label, "Push +1 rep")
    }

    func testRpeTwoLowsAddWeight() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 6)
        addSet(to: exercise, reps: 8, weight: 80, rpe: 5)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.weight, 82.5, "Two-in-a-row low RPE should add the muscle-group increment")
        XCTAssertEqual(r?.reps, 8)
        XCTAssertEqual(r?.label, "Add weight")
    }

    func testRpeSevenMatches() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 7)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.label, "Match it")
        XCTAssertEqual(r?.reps, 8)
        XCTAssertEqual(r?.weight, 80)
    }

    func testRpeEightMatches() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 8)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.label, "Match it")
    }

    func testRpeNineFlagsLastHardSet() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 9)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.label, "Last hard set")
        XCTAssertEqual(r?.reps, 8)
    }

    func testRpeTenDropsARepEarlyInSession() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 10)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.label, "Drop a rep")
        XCTAssertEqual(r?.reps, 7)
    }

    func testRpeTenAfterThreeSetsCallsIt() {
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80, rpe: 8)
        addSet(to: exercise, reps: 8, weight: 80, rpe: 9)
        addSet(to: exercise, reps: 6, weight: 80, rpe: 10)
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .rpeCoach)
        XCTAssertEqual(r?.label, "Call it")
    }

    func testNoRpeFallsBackToRepeatLast() {
        // Sanity check: the new coach must NOT engage without an RPE signal.
        let exercise = makeExercise(name: "Bench")
        addSet(to: exercise, reps: 8, weight: 80) // no rpe
        let r = SuggestedSetEngine.suggestNextSet(for: exercise, history: [exercise])
        XCTAssertEqual(r?.source, .repeatInSession,
                       "Without RPE we should fall back to the conservative repeat-last default")
    }

    // MARK: - Helpers

    private func makeExercise(name: String, category: MuscleGroup = .chest) -> Exercise {
        let workout = Workout(name: "Today")
        let exercise = Exercise(name: name, workout: workout, category: category)
        workout.exercises.append(exercise)
        return exercise
    }

    private func makeHistoricalExercise(
        name: String,
        daysAgo: Int,
        reps: Int,
        weight: Double,
        rpe: Int? = nil,
        category: MuscleGroup = .chest
    ) -> Exercise {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let workout = Workout(name: "Past", date: date)
        workout.endTime = date.addingTimeInterval(3600)
        let exercise = Exercise(name: name, workout: workout, category: category)
        exercise.sets.append(ExerciseSet(reps: reps, weight: weight, rpe: rpe, exercise: exercise))
        workout.exercises.append(exercise)
        return exercise
    }

    @discardableResult
    private func addSet(to exercise: Exercise, reps: Int, weight: Double,
                        isWarmUp: Bool = false, rpe: Int? = nil) -> ExerciseSet {
        let set = ExerciseSet(reps: reps, weight: weight,
                              isWarmUp: isWarmUp, rpe: rpe, exercise: exercise)
        exercise.sets.append(set)
        return set
    }
}
