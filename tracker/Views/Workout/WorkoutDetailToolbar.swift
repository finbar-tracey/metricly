import SwiftUI
import SwiftData

struct WorkoutDetailToolbar: ViewModifier {
    @Environment(\.appServices) private var appServices
    let workout: Workout
    let weightUnit: WeightUnit
    let sortedExercises: [Exercise]
    @Binding var showingEditWorkout: Bool
    @Binding var showWorkoutTimer: Bool
    @Binding var showingFinishSheet: Bool
    @Binding var showingShare: Bool
    @Binding var shareItems: [Any]
    @Binding var showTemplateSaved: Bool
    @Binding var showDeleteConfirm: Bool
    @Binding var showFocusPrompt: Bool
    @Binding var showFocusEndReminder: Bool
    @Binding var exerciseToDelete: Exercise?
    @Binding var linkingSupersetFor: Exercise?
    let durationTracker: WorkoutDurationTracker
    let settings: UserSettings
    let onSaveAsTemplate: () -> Void
    let onDuplicate: () -> Void
    let onDeleteWorkout: () -> Void
    let onDeleteExercise: (Exercise) -> Void
    let onLinkSuperset: (Exercise, Exercise) -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !workout.isTemplate && !workout.isFinished {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            showingFinishSheet = true
                        } label: {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        .accessibilityLabel("Finish workout")
                    }
                    Button {
                        showWorkoutTimer = true
                    } label: {
                        Image(systemName: "stopwatch")
                    }
                    .accessibilityLabel("Workout Timers")
                    Menu {
                        Button {
                            showingEditWorkout = true
                        } label: {
                            Label("Edit Workout", systemImage: "pencil")
                        }
                        Button {
                            onSaveAsTemplate()
                        } label: {
                            Label("Save as Template", systemImage: "doc.on.doc")
                        }
                        .accessibilityLabel("Save as template")
                        Button {
                            onDuplicate()
                        } label: {
                            Label("Duplicate Workout", systemImage: "plus.square.on.square")
                        }
                        Button {
                            shareItems = [WorkoutSummaryFormatter.plainText(for: workout, weightUnit: weightUnit)]
                            showingShare = true
                        } label: {
                            Label("Share as Text", systemImage: "text.quote")
                        }
                        Button {
                            let card = WorkoutShareCardView(workout: workout, weightUnit: weightUnit)
                            if let image = card.renderImage() {
                                shareItems = [image]
                                showingShare = true
                            }
                        } label: {
                            Label("Share as Image", systemImage: "photo")
                        }
                        Divider()
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Workout options")
                }
            }
            .sheet(isPresented: $showingEditWorkout) {
                EditWorkoutSheet(workout: workout)
            }
            .sheet(isPresented: $showWorkoutTimer) {
                NavigationStack {
                    WorkoutTimerView()
                }
            }
            .sheet(isPresented: $showingFinishSheet) {
                durationTracker.tearDown()
                if workout.isFinished {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    if settings.focusModeReminder {
                        showFocusEndReminder = true
                    }
                }
            } content: {
                FinishWorkoutSheet(workout: workout)
            }
            .sheet(isPresented: $showingShare) {
                ShareSheet(items: shareItems)
            }
            .alert("Template Saved", isPresented: $showTemplateSaved) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("\"\(workout.name)\" has been saved as a template. You can use it when creating new workouts.")
            }
            .alert("Delete Exercise?", isPresented: Binding(
                get: { exerciseToDelete != nil },
                set: { if !$0 { exerciseToDelete = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let exercise = exerciseToDelete {
                        onDeleteExercise(exercise)
                        exerciseToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) { exerciseToDelete = nil }
            } message: {
                if let exercise = exerciseToDelete {
                    Text("Are you sure you want to delete \"\(exercise.name)\" and all its sets?")
                }
            }
            .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete \"\(workout.name)\"", role: .destructive) {
                    onDeleteWorkout()
                }
            } message: {
                Text("This will permanently delete this workout and all its data. This cannot be undone.")
            }
            .alert("Enable Focus Mode?", isPresented: $showFocusPrompt) {
                Button("Open Settings") {
                    Task { await appServices.openSettings() }
                }
                Button("Not Now", role: .cancel) {}
            } message: {
                Text("Enable your Fitness Focus to silence notifications during your workout. Open Settings, then tap Focus.")
            }
            .alert("Workout Complete!", isPresented: $showFocusEndReminder) {
                Button("Open Settings") {
                    Task { await appServices.openSettings() }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Don't forget to turn off your Fitness Focus mode. Open Settings, then tap Focus.")
            }
            .sheet(item: $linkingSupersetFor) { sourceExercise in
                SupersetPickerSheet(
                    source: sourceExercise,
                    candidates: sortedExercises.filter { $0.persistentModelID != sourceExercise.persistentModelID },
                    onPick: { partner in
                        onLinkSuperset(sourceExercise, partner)
                        linkingSupersetFor = nil
                    },
                    onCancel: { linkingSupersetFor = nil }
                )
            }
    }
}
