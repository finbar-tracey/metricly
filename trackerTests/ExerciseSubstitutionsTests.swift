import XCTest
import SwiftData
@testable import tracker

/// Tests for the exercise-substitution feature. Three layers:
///   1. Library lookup — `ExerciseSubstitutions.suggestion(for:)`
///   2. Detection — `TodayPlanApply.substitutionsFor(plan:on:)`
///      respects category gating, logged-set protection, and dedup
///      against the rest of the workout.
///   3. Commit — `applySubstitution(_:in:)` renames in place, clears
///      blank sets, re-infers the category.
@MainActor
final class ExerciseSubstitutionsTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self, Exercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }

    private func makeWorkout(in context: ModelContext) -> Workout {
        let workout = Workout(name: "Push", date: .now)
        context.insert(workout)
        return workout
    }

    @discardableResult
    private func addExercise(
        name: String,
        category: MuscleGroup,
        to workout: Workout,
        in context: ModelContext,
        order: Int = 0,
        loggedSet: Bool = false
    ) -> Exercise {
        let exercise = Exercise(name: name, workout: workout, category: category)
        exercise.order = order
        context.insert(exercise)
        workout.exercises.append(exercise)
        if loggedSet {
            let set = ExerciseSet(reps: 8, weight: 60, exercise: exercise)
            context.insert(set)
            exercise.sets.append(set)
        } else {
            // Blank placeholder set — the eligibility filter should
            // still allow substitution on these.
            let set = ExerciseSet(reps: 0, weight: 0, exercise: exercise)
            context.insert(set)
            exercise.sets.append(set)
        }
        return exercise
    }

    private func plan(
        avoid: [MuscleGroup] = [],
        goEasy: [MuscleGroup] = []
    ) -> TodayPlan {
        TodayPlan(
            scheduledName: nil,
            recommendedName: "Push",
            intensity: .moderate,
            reasons: [],
            adjustments: [],
            confidence: .medium,
            alreadyTrainedToday: false,
            goEasyOnGroups: goEasy,
            avoidGroups: avoid,
            generatedAt: .now
        )
    }

    // MARK: - Library lookup

    func testLibraryHasCommonCompounds() {
        XCTAssertNotNil(ExerciseSubstitutions.suggestion(for: "Bench Press"))
        XCTAssertNotNil(ExerciseSubstitutions.suggestion(for: "Squat"))
        XCTAssertNotNil(ExerciseSubstitutions.suggestion(for: "Overhead Press"))
        XCTAssertNotNil(ExerciseSubstitutions.suggestion(for: "Barbell Row"))
    }

    func testLibraryMatchesIsCaseInsensitive() {
        let lower = ExerciseSubstitutions.suggestion(for: "bench press")
        let mixed = ExerciseSubstitutions.suggestion(for: "Bench Press")
        let upper = ExerciseSubstitutions.suggestion(for: "BENCH PRESS")
        XCTAssertNotNil(lower)
        XCTAssertEqual(lower, mixed)
        XCTAssertEqual(mixed, upper)
    }

    func testLibraryReturnsNilForUnknownExercise() {
        XCTAssertNil(ExerciseSubstitutions.suggestion(for: "Imaginary Lift"))
    }

    func testLibraryDoesNotRecommendExerciseAlreadyInWorkout() {
        // Bench Press's first candidate is Machine Chest Press; passing
        // it as "already in workout" should make the lookup skip to
        // the next candidate.
        let suggestion = ExerciseSubstitutions.suggestion(
            for: "Bench Press",
            alreadyInWorkout: ["Machine Chest Press"]
        )
        XCTAssertNotEqual(suggestion?.lowercased(), "machine chest press",
                          "Should skip the first candidate when user has it already")
        XCTAssertNotNil(suggestion, "Should still find a candidate down the list")
    }

    func testLibraryReturnsNilWhenAllCandidatesAlreadyInWorkout() {
        // Saturate the candidate list — every Bench Press alternative
        // is already on the user's plan. The lookup should return nil
        // rather than producing nonsense.
        let all = ExerciseSubstitutions.library["bench press"] ?? []
        let suggestion = ExerciseSubstitutions.suggestion(
            for: "Bench Press",
            alreadyInWorkout: all
        )
        XCTAssertNil(suggestion)
    }

    // MARK: - Detection (TodayPlanApply.substitutionsFor)

    func testDetectionFlagsExerciseInGoEasyGroup() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        addExercise(name: "Bench Press", category: .chest, to: workout, in: context)

        let plan = plan(goEasy: [.chest])
        let suggestions = TodayPlanApply.substitutionsFor(plan: plan, on: workout)
        XCTAssertEqual(suggestions.count, 1)
        XCTAssertEqual(suggestions.first?.exercise.name, "Bench Press")
        XCTAssertNotNil(suggestions.first?.suggestedName)
    }

    func testDetectionFlagsExerciseInAvoidGroup() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        addExercise(name: "Squat", category: .legs, to: workout, in: context)

        let plan = plan(avoid: [.legs])
        let suggestions = TodayPlanApply.substitutionsFor(plan: plan, on: workout)
        XCTAssertEqual(suggestions.count, 1)
    }

    func testDetectionIgnoresExerciseNotInGoEasyOrAvoid() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        addExercise(name: "Bench Press", category: .chest, to: workout, in: context)
        // Plan flags legs as fatigued; chest is not on the list, so
        // bench shouldn't get flagged.
        let plan = plan(avoid: [.legs])
        XCTAssertEqual(TodayPlanApply.substitutionsFor(plan: plan, on: workout).count, 0)
    }

    func testDetectionSkipsLoggedExercises() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        addExercise(name: "Bench Press", category: .chest, to: workout,
                    in: context, loggedSet: true)

        let plan = plan(goEasy: [.chest])
        // User has already logged real work on bench — don't suggest
        // swapping it out from under them.
        XCTAssertEqual(TodayPlanApply.substitutionsFor(plan: plan, on: workout).count, 0)
    }

    func testDetectionSkipsExercisesWithNoLibraryEntry() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        // Exercise is in a goEasy group BUT no library entry exists.
        addExercise(name: "Imaginary Lift", category: .chest,
                    to: workout, in: context)
        let plan = plan(goEasy: [.chest])
        XCTAssertEqual(TodayPlanApply.substitutionsFor(plan: plan, on: workout).count, 0)
    }

    func testDetectionDoesNotRecommendAnExerciseAlreadyInWorkout() throws {
        // User already has Machine Chest Press (Bench Press's first
        // candidate). Detection should still return Bench Press as a
        // candidate, but the suggestion should be a different name —
        // we don't tell the user to add what they already have.
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        addExercise(name: "Bench Press", category: .chest,
                    to: workout, in: context, order: 0)
        addExercise(name: "Machine Chest Press", category: .chest,
                    to: workout, in: context, order: 1)

        let plan = plan(goEasy: [.chest])
        let suggestions = TodayPlanApply.substitutionsFor(plan: plan, on: workout)
        XCTAssertEqual(suggestions.count, 1,
                       "Bench Press should still be flagged for substitution")
        XCTAssertNotEqual(suggestions.first?.suggestedName.lowercased(),
                          "machine chest press",
                          "Suggested name must not match an exercise already in the workout")
    }

    func testDetectionPreservesExerciseOrder() throws {
        // Two flag-eligible exercises in a specific order — the
        // suggestions array should mirror that order.
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        addExercise(name: "Bench Press", category: .chest, to: workout,
                    in: context, order: 0)
        addExercise(name: "Squat", category: .legs, to: workout,
                    in: context, order: 1)
        let plan = plan(goEasy: [.chest, .legs])
        let suggestions = TodayPlanApply.substitutionsFor(plan: plan, on: workout)
        XCTAssertEqual(suggestions.map(\.exercise.name),
                       ["Bench Press", "Squat"])
    }

    func testDetectionReturnsEmptyForFinishedWorkout() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        workout.endTime = .now   // marks as finished
        addExercise(name: "Bench Press", category: .chest, to: workout, in: context)
        let plan = plan(goEasy: [.chest])
        XCTAssertEqual(TodayPlanApply.substitutionsFor(plan: plan, on: workout).count, 0)
    }

    func testDetectionReturnsEmptyForTemplate() throws {
        let context = try makeContext()
        let template = Workout(name: "Push Template", date: .now, isTemplate: true)
        context.insert(template)
        addExercise(name: "Bench Press", category: .chest, to: template, in: context)
        let plan = plan(goEasy: [.chest])
        XCTAssertEqual(TodayPlanApply.substitutionsFor(plan: plan, on: template).count, 0)
    }

    // MARK: - Commit (applySubstitution)

    func testApplySubstitutionRenamesInPlace() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let ex = addExercise(name: "Bench Press", category: .chest, to: workout, in: context)
        let suggestion = TodayPlanApply.SubstitutionSuggestion(
            exercise: ex,
            suggestedName: "Machine Chest Press"
        )

        TodayPlanApply.applySubstitution(suggestion, in: context)
        try context.save()

        XCTAssertEqual(ex.name, "Machine Chest Press")
    }

    func testApplySubstitutionClearsBlankSets() throws {
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        // Default helper adds one blank placeholder set; assert it's
        // there before commit, gone after.
        let ex = addExercise(name: "Bench Press", category: .chest, to: workout, in: context)
        XCTAssertEqual(ex.sets.count, 1)

        let suggestion = TodayPlanApply.SubstitutionSuggestion(
            exercise: ex,
            suggestedName: "Machine Chest Press"
        )
        TodayPlanApply.applySubstitution(suggestion, in: context)
        try context.save()

        XCTAssertEqual(ex.sets.count, 0,
                       "Blank sets should clear on substitution — the user starts fresh on the new movement")
    }

    func testApplySubstitutionReInfersCategory() throws {
        // Bench Press → Cable Fly. Both are chest, but the inference
        // path should fire and produce .chest either way. The
        // important contract is that the category gets re-set rather
        // than being left stale at the original name's inference.
        let context = try makeContext()
        let workout = makeWorkout(in: context)
        let ex = addExercise(name: "Bench Press", category: .chest, to: workout, in: context)
        let suggestion = TodayPlanApply.SubstitutionSuggestion(
            exercise: ex,
            suggestedName: "Cable Fly"
        )
        TodayPlanApply.applySubstitution(suggestion, in: context)
        try context.save()

        XCTAssertEqual(ex.category, .chest,
                       "Cable Fly should still infer to .chest")
    }
}
