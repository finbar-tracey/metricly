//
//  TodayPlanApplyTests.swift
//  trackerTests
//
//  Covers the selection logic that drives the "Apply Adjustments"
//  feature. Exercises and sets are built standalone (no ModelContext)
//  so we can assert on the Preview without spinning up an in-memory
//  SwiftData container — the apply pass is a thin wrapper over the
//  same Preview that just calls `context.delete`, so testing Preview
//  in isolation covers the safety-critical branches.
//

import XCTest
import SwiftData
@testable import tracker

@MainActor
final class TodayPlanApplyTests: XCTestCase {

    // MARK: - avoidGroups removal

    func testRemovesUnloggedExerciseInAvoidGroups() {
        let workout = makeWorkout()
        let chest = addExercise(to: workout, name: "Bench", category: .chest, workingSets: 3, logged: false)
        let plan = makePlan(intensity: .moderate, avoidGroups: [.chest])

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertEqual(preview.exercisesToRemove.map(\.name), [chest.name])
        XCTAssertTrue(preview.exercisesToTrim.isEmpty)
    }

    func testKeepsLoggedExerciseInAvoidGroups() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Bench", category: .chest, workingSets: 3, logged: true)
        let plan = makePlan(intensity: .moderate, avoidGroups: [.chest])

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertTrue(preview.exercisesToRemove.isEmpty,
                       "Must not delete an exercise the user has already logged sets for")
    }

    // MARK: - light-intensity trim

    func testLightIntensityTrimsTrailingBlankWorkingSet() {
        let workout = makeWorkout()
        let ex = addExercise(to: workout, name: "Row", category: .back, workingSets: 3, logged: false)
        let plan = makePlan(intensity: .light)

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertEqual(preview.exercisesToTrim.map(\.name), [ex.name])
    }

    func testLightIntensityDoesNotTrimWhenOnlyOneWorkingSet() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Solo", category: .back, workingSets: 1, logged: false)
        let plan = makePlan(intensity: .light)

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertTrue(preview.exercisesToTrim.isEmpty,
                       "Refuse to zero out an exercise by trimming its only set")
    }

    func testLightIntensityDoesNotTrimWhenLastSetIsLogged() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Row", category: .back, workingSets: 3, logged: true)
        let plan = makePlan(intensity: .light)

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertTrue(preview.exercisesToTrim.isEmpty,
                       "Trimming a logged set would destroy the user's data")
    }

    func testModerateIntensityNeverTrims() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Row", category: .back, workingSets: 3, logged: false)
        let plan = makePlan(intensity: .moderate)

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertTrue(preview.exercisesToTrim.isEmpty)
    }

    // MARK: - guard rails

    func testFinishedWorkoutIsNoOp() {
        let workout = makeWorkout(finished: true)
        _ = addExercise(to: workout, name: "Bench", category: .chest, workingSets: 3, logged: false)
        let plan = makePlan(intensity: .light, avoidGroups: [.chest])

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertTrue(preview.isEmpty)
    }

    func testTemplateIsNoOp() {
        let template = Workout(name: "Push template", isTemplate: true)
        _ = addExercise(to: template, name: "Bench", category: .chest, workingSets: 3, logged: false)
        let plan = makePlan(intensity: .light, avoidGroups: [.chest])

        let preview = TodayPlanApply.preview(plan: plan, on: template)
        XCTAssertTrue(preview.isEmpty)
    }

    func testEmptyWorkoutHasEmptyPreview() {
        let workout = makeWorkout()
        let plan = makePlan(intensity: .light, avoidGroups: [.chest])
        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertTrue(preview.isEmpty)
        XCTAssertTrue(preview.summary.contains("aligns"))
    }

    // MARK: - Block-aware deeper trim
    //
    // During a deload week, the trim depth doubles from 1 → 2 sets per
    // exercise — the deload's whole point is meaningful volume cut, not
    // a marginal one. The block context is opt-in via the `currentBlock`
    // parameter so non-deload callers (and the v1.7 default-arg
    // overload) behave exactly as before.

    func testDeloadBlockTrimsTwoSetsPerExercise() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Row", category: .back, workingSets: 4, logged: false)
        let plan = makePlan(intensity: .light)
        let deload = makeBlock(phase: .deload)

        let preview = TodayPlanApply.preview(plan: plan, on: workout, currentBlock: deload)
        XCTAssertEqual(preview.trimSetsPerExercise, 2,
                       "Deload week deepens the trim to 2 sets per exercise")
        XCTAssertEqual(preview.exercisesToTrim.map(\.name), ["Row"])
    }

    func testAccumulateBlockKeepsSingleTrim() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Row", category: .back, workingSets: 4, logged: false)
        let plan = makePlan(intensity: .light)
        let accumulate = makeBlock(phase: .accumulate)

        let preview = TodayPlanApply.preview(plan: plan, on: workout, currentBlock: accumulate)
        XCTAssertEqual(preview.trimSetsPerExercise, 1,
                       "Accumulate week leaves the trim at the v1.7 single-set default")
    }

    func testNoBlockKeepsSingleTrim() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Row", category: .back, workingSets: 4, logged: false)
        let plan = makePlan(intensity: .light)

        let preview = TodayPlanApply.preview(plan: plan, on: workout)
        XCTAssertEqual(preview.trimSetsPerExercise, 1,
                       "Default (nil block) keeps v1.7 single-set behaviour")
    }

    func testDeloadSummaryStringReadsTwoSets() {
        let workout = makeWorkout()
        _ = addExercise(to: workout, name: "Row", category: .back, workingSets: 4, logged: false)
        let plan = makePlan(intensity: .light)
        let deload = makeBlock(phase: .deload)

        let preview = TodayPlanApply.preview(plan: plan, on: workout, currentBlock: deload)
        XCTAssertTrue(preview.summary.contains("drop 2 sets"),
                      "Summary must reflect the deeper trim. Got: \(preview.summary)")
    }

    func testApplyDuringDeloadActuallyRemovesTwoSets() throws {
        let context = try makeContext()
        let workout = Workout(name: "Push", date: .now)
        context.insert(workout)

        let ex = Exercise(name: "Row", workout: workout, category: .back)
        ex.order = 0
        context.insert(ex)
        workout.exercises.append(ex)
        for _ in 0..<4 {
            let s = ExerciseSet(reps: 0, weight: 0, isWarmUp: false, exercise: ex)
            ex.sets.append(s)
            context.insert(s)
        }

        let plan = makePlan(intensity: .light)
        let deload = makeBlock(phase: .deload)
        TodayPlanApply.apply(plan: plan, to: workout, in: context, currentBlock: deload)
        try context.save()

        XCTAssertEqual(ex.sets.count, 2,
                       "Started with 4 blank working sets; deload trim of 2 → 2 remaining")
    }

    func testDeloadTrimFloorsAtTwoRemainingSets() throws {
        // Three working sets going in. Deload wants to drop 2, but the
        // trimCandidate guard refuses to leave fewer than 2 working
        // sets behind — so only ONE set gets removed even in deload
        // mode. That's the same safety rail as non-deload, just
        // hit earlier.
        let context = try makeContext()
        let workout = Workout(name: "Push", date: .now)
        context.insert(workout)

        let ex = Exercise(name: "Row", workout: workout, category: .back)
        ex.order = 0
        context.insert(ex)
        workout.exercises.append(ex)
        for _ in 0..<3 {
            let s = ExerciseSet(reps: 0, weight: 0, isWarmUp: false, exercise: ex)
            ex.sets.append(s)
            context.insert(s)
        }

        let plan = makePlan(intensity: .light)
        let deload = makeBlock(phase: .deload)
        TodayPlanApply.apply(plan: plan, to: workout, in: context, currentBlock: deload)
        try context.save()

        XCTAssertEqual(ex.sets.count, 2,
                       "Floor: trim refuses to leave fewer than 2 working sets — stops after 1 even in deload")
    }

    // MARK: - Helpers

    private func makeWorkout(finished: Bool = false) -> Workout {
        let w = Workout(name: "Today", date: .now)
        if finished { w.endTime = .now }
        return w
    }

    @discardableResult
    private func addExercise(
        to workout: Workout,
        name: String,
        category: MuscleGroup,
        workingSets: Int,
        logged: Bool
    ) -> Exercise {
        let ex = Exercise(name: name, workout: workout, category: category)
        ex.order = workout.exercises.count
        for _ in 0..<workingSets {
            let s = ExerciseSet(reps: 0, weight: 0, isWarmUp: false, exercise: ex)
            ex.sets.append(s)
        }
        if logged, let last = ex.sets.last {
            last.reps = 8
            last.weight = 80
        }
        workout.exercises.append(ex)
        return ex
    }

    private func makePlan(
        intensity: TodayPlan.Intensity,
        avoidGroups: [MuscleGroup] = []
    ) -> TodayPlan {
        TodayPlan(
            scheduledName: nil,
            recommendedName: "Test",
            intensity: intensity,
            reasons: [],
            adjustments: ["test adjustment"],
            confidence: .medium,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: avoidGroups,
            generatedAt: .now
        )
    }

    private func makeBlock(phase: TrainingBlock.Phase) -> TrainingBlock {
        // A 4-week block starting 7 days ago — solidly mid-block so any
        // contains() check would return true if it were used. The
        // block-aware trim only inspects `phase`, but keeping the dates
        // sane defends against future contains-gated logic landing on
        // top of this.
        TrainingBlock(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
            weekCount: 4,
            phase: phase
        )
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Workout.self, Exercise.self, ExerciseSet.self,
            configurations: config
        )
        return ModelContext(container)
    }
}
