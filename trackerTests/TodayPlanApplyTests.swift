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
@testable import tracker

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
}
