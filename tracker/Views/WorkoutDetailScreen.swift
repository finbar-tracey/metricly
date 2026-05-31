import SwiftUI
import SwiftData
import UIKit

/// Active workout UI — no SwiftData `@Query` (data from [`WorkoutDetailQueryContainer`]).
struct WorkoutDetailScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appServices) private var appServices

    let workout: Workout
    let allExercises: [Exercise]
    let settingsArray: [UserSettings]
    let trainingBlocks: [TrainingBlock]

    @State private var newExerciseName = ""
    @State private var newExerciseCategory: MuscleGroup = .other
    @State private var showingEditWorkout = false
    @State private var showTemplateSaved = false
    @State private var showingSuggestions = false
    @State private var exerciseToDelete: Exercise?
    @State private var elapsedTime = ""
    @State private var durationTracker = WorkoutDurationTracker()
    @State private var linkingSupersetFor: Exercise?
    @State private var showingFinishSheet = false
    @State private var showingShare = false
    @State private var shareItems: [Any] = []
    @State private var showDeleteConfirm = false
    @State private var showWorkoutTimer = false
    @State private var showFocusPrompt = false
    @State private var showFocusEndReminder = false
    @State private var planAdjustments: TodayPlan?
    @State private var planAdjustmentsDismissed = false
    @State private var dismissedSubstitutions: Set<PersistentIdentifier> = []

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var sortedExercises: [Exercise] {
        WorkoutDetailExerciseListSection.sortedExercises(in: workout)
    }

    private var suggestions: [String] {
        let history = Set(allExercises.map(\.name))
        let current = Set(workout.exercises.map(\.name))
        let available = history.subtracting(current)
        if newExerciseName.isEmpty {
            return available.sorted()
        }
        return available.filter {
            $0.localizedCaseInsensitiveContains(newExerciseName)
        }.sorted()
    }

    var body: some View {
        WorkoutDetailScreenSections.activeWorkoutList(
            workout: workout,
            weightUnit: weightUnit,
            allExercises: allExercises,
            elapsedTime: elapsedTime,
            planAdjustments: planAdjustments,
            planAdjustmentsDismissed: planAdjustmentsDismissed,
            trainingBlocks: trainingBlocks,
            dismissedSubstitutions: dismissedSubstitutions,
            sortedExercises: sortedExercises,
            suggestions: suggestions,
            newExerciseName: $newExerciseName,
            newExerciseCategory: $newExerciseCategory,
            showingSuggestions: $showingSuggestions,
            exerciseToDelete: $exerciseToDelete,
            linkingSupersetFor: $linkingSupersetFor,
            onDismissPlan: { withAnimation { planAdjustmentsDismissed = true } },
            onApplyPlan: applyPlanAdjustments,
            onSwapSubstitution: { suggestion in
                withAnimation {
                    TodayPlanApply.applySubstitution(suggestion, in: modelContext)
                    modelContext.saveOrLog()
                }
            },
            onKeepSubstitution: { id in
                withAnimation { _ = dismissedSubstitutions.insert(id) }
            },
            onAddExercise: addExercise,
            onAutoSelectCategory: autoSelectCategory,
            onMoveExercises: { source, destination in
                WorkoutDetailExerciseListSection.moveExercises(
                    in: workout,
                    from: source,
                    to: destination
                )
            },
            onUnlinkSuperset: { exercise in
                WorkoutDetailExerciseListSection.unlinkSuperset(exercise)
            }
        )
        .navigationTitle(workout.name)
        .navigationDestination(for: Exercise.self) { exercise in
            ExerciseDetailView(exercise: exercise)
        }
        .safeAreaInset(edge: .bottom) {
            WorkoutDetailScreenSections.bottomDock(
                workout: workout,
                weightUnit: weightUnit,
                allExercises: allExercises,
                onQuickAddSet: { exercise in
                    WorkoutDetailDock.quickAddSet(
                        for: exercise,
                        allExercises: allExercises,
                        in: modelContext
                    )
                    WorkoutDetailLiveActivity.update(for: workout, activity: appServices.workoutActivity)
                }
            )
        }
        .modifier(WorkoutDetailToolbar(
            workout: workout,
            weightUnit: weightUnit,
            sortedExercises: sortedExercises,
            showingEditWorkout: $showingEditWorkout,
            showWorkoutTimer: $showWorkoutTimer,
            showingFinishSheet: $showingFinishSheet,
            showingShare: $showingShare,
            shareItems: $shareItems,
            showTemplateSaved: $showTemplateSaved,
            showDeleteConfirm: $showDeleteConfirm,
            showFocusPrompt: $showFocusPrompt,
            showFocusEndReminder: $showFocusEndReminder,
            exerciseToDelete: $exerciseToDelete,
            linkingSupersetFor: $linkingSupersetFor,
            durationTracker: durationTracker,
            settings: settings,
            onSaveAsTemplate: saveAsTemplate,
            onDuplicate: duplicateWorkout,
            onDeleteWorkout: {
                modelContext.delete(workout)
                dismiss()
            },
            onDeleteExercise: { exercise in
                modelContext.delete(exercise)
            },
            onLinkSuperset: { source, partner in
                WorkoutDetailExerciseListSection.linkSuperset(source, with: partner, in: workout)
            }
        ))
        .onAppear {
            updateElapsedTime()
            startDurationTracking()
            WorkoutDetailLiveActivity.startIfNeeded(for: workout, activity: appServices.workoutActivity)
            if settings.focusModeReminder && !workout.isFinished && !workout.isTemplate {
                showFocusPrompt = true
            }
            planAdjustments = WorkoutDetailScreenSections.planAdjustmentsForWorkout(workout)
        }
        .onDisappear {
            durationTracker.tearDown()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && !workout.isFinished && !workout.isTemplate {
                updateElapsedTime()
                if workout.startTime != nil {
                    startDurationTracking()
                }
            }
        }
    }

    private func addExercise() {
        let name = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let exercise = Exercise(name: name, workout: workout, category: newExerciseCategory)
        exercise.order = (workout.exercises.map(\.order).max() ?? -1) + 1
        modelContext.insert(exercise)
        workout.exercises.append(exercise)
        newExerciseName = ""
        newExerciseCategory = .other
        showingSuggestions = false
        WorkoutDetailLiveActivity.update(for: workout, activity: appServices.workoutActivity)
    }

    private func autoSelectCategory() {
        let trimmed = newExerciseName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        if let previous = allExercises.first(where: { $0.name == trimmed && $0.category != nil }) {
            newExerciseCategory = previous.category!
        }
    }

    private func saveAsTemplate() {
        let template = Workout(name: workout.name, isTemplate: true)
        modelContext.insert(template)
        template.copyExercises(from: workout.exercises, into: modelContext)
        showTemplateSaved = true
    }

    private func duplicateWorkout() {
        let newWorkout = Workout(name: workout.name, date: .now)
        modelContext.insert(newWorkout)
        newWorkout.copyExercises(from: workout.exercises, into: modelContext)
        HapticsManager.success()
    }

    private func applyPlanAdjustments(_ plan: TodayPlan) {
        _ = TodayPlanApply.apply(
            plan: plan,
            to: workout,
            in: modelContext,
            currentBlock: TrainingBlockEngine.currentBlock(in: trainingBlocks)
        )
        modelContext.saveOrLog()
        AppLifecycleCoordinator.refreshExtensions(modelContainer: modelContext.container)
        withAnimation { planAdjustmentsDismissed = true }
    }

    private func startDurationTracking() {
        guard !workout.isFinished, !workout.isTemplate, let start = workout.startTime else { return }
        durationTracker.start(from: start)
        updateElapsedTime()
    }

    private func updateElapsedTime() {
        if let start = workout.startTime {
            durationTracker.sync(from: start)
            elapsedTime = durationTracker.formattedElapsed
        } else if let duration = workout.formattedDuration {
            elapsedTime = duration
        }
    }
}
