import SwiftUI
import SwiftData
import UIKit

struct ExerciseDetailView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.weightUnit) var weightUnit
    @Environment(\.scenePhase) private var scenePhase
    @Query var allExercises: [Exercise]
    @Query var settingsArray: [UserSettings]
    @Query var liftGoals: [LiftGoal]
    let exercise: Exercise

    init(exercise: Exercise) {
        self.exercise = exercise
        let name = exercise.name
        _allExercises = Query(filter: #Predicate<Exercise> { $0.name == name })
    }

    @State var session = ExerciseSessionState()
    @AppStorage("celebrationsEnabled") var celebrationsEnabled = true
    @FocusState var isWeightFieldFocused: Bool

    var body: some View {
        exerciseDetailList
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Color(.systemGroupedBackground))
        .overlay(alignment: .top) {
            if celebrationsEnabled {
                ExerciseCelebrationOverlay(
                    session: session,
                    exerciseName: exercise.name,
                    weightUnit: weightUnit
                )
            }
        }
        .navigationTitle(exercise.name)
        .toolbar { exerciseToolbar }
        .navigationDestination(for: FormGuideDestination.self) { dest in
            ExerciseGuideView(exerciseName: dest.exerciseName)
        }
        .navigationDestination(for: SubstitutionDestination.self) { dest in
            ExerciseSubstitutionsView(exerciseName: dest.exerciseName)
        }
        .alert("Edit Exercise", isPresented: $session.isEditingName) {
            TextField("Name", text: $session.editedName)
            Button("Save") { exercise.name = session.editedName }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $session.editingSet) { exerciseSet in
            EditSetSheet(
                exerciseSet: exerciseSet,
                reps: session.editReps,
                weight: session.editWeight,
                distanceUnit: weightUnit.distanceUnit
            )
        }
        .sheet(isPresented: $session.showingRestEditor) {
            ExerciseRestEditorSheet(
                exercise: exercise,
                defaultGlobal: settingsArray.first?.defaultRestDuration ?? 90
            ) {
                session.restTimer.restDuration = exercise.customRestDuration
                    ?? (settingsArray.first?.defaultRestDuration ?? 90)
            }
            .presentationDetents([.medium])
        }
        .navigationDestination(for: PlateCalcDestination.self) { _ in
            PlateCalculatorView()
        }
        .safeAreaInset(edge: .bottom) { exerciseBottomInset }
        .onAppear(perform: onAppearSetup)
        .onDisappear {
            isWeightFieldFocused = false
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            session.restTimer.tearDown()
        }
        .scrollDismissesKeyboard(.immediately)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                session.restTimer.syncOnReturnToForeground()
            }
        }
    }
}

struct PlateCalcDestination: Hashable {}

#if DEBUG
#Preview("Logging — set rows") {
    let container = try! ModelContainer(
        for: MetriclySchema.schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let ctx = container.mainContext

    let pastWorkout = Workout(name: "Push", date: .now.addingTimeInterval(-7 * 86400))
    ctx.insert(pastWorkout)
    let pastEx = Exercise(name: "Bench Press", workout: pastWorkout, category: .chest)
    ctx.insert(pastEx)
    pastEx.sets = [ExerciseSet(reps: 8, weight: 80, exercise: pastEx)]

    let workout = Workout(name: "Push")
    ctx.insert(workout)
    let exercise = Exercise(name: "Bench Press", workout: workout, category: .chest)
    ctx.insert(exercise)
    exercise.sets = [
        ExerciseSet(reps: 10, weight: 40, isWarmUp: true, exercise: exercise),
        ExerciseSet(reps: 8, weight: 80, rpe: 8, exercise: exercise),
        ExerciseSet(reps: 6, weight: 85, rpe: 9, exercise: exercise),
    ]

    return NavigationStack { ExerciseDetailView(exercise: exercise) }
        .modelContainer(container)
}
#endif
