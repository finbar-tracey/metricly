import SwiftUI
import SwiftData

struct SmartSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.appServices) private var appServices
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]

    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var createdWorkout: Workout?
    @State private var recoveryResult: RecoveryResult = .empty

    private var muscleReadiness: [(MuscleGroup, Double)] {
        SmartSuggestionsEngine.muscleReadiness(from: recoveryResult)
    }

    private var suggestedWorkoutType: String { recoveryResult.suggestedWorkoutType }

    private var suggestedExercises: [SuggestedExercise] {
        SmartSuggestionsEngine.suggestedExercises(recovery: recoveryResult, workouts: workouts)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                SmartSuggestionsSections.heroCard(
                    suggestedWorkoutType: suggestedWorkoutType,
                    muscleReadiness: muscleReadiness
                )
                if !suggestedExercises.isEmpty {
                    SmartSuggestionsSections.suggestionsCard(
                        suggestions: suggestedExercises,
                        onCreateWorkout: createWorkoutFromSuggestions
                    )
                }
                SmartSuggestionsSections.howItWorksCard()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Smart Suggestions")
        .navigationDestination(item: $createdWorkout) { workout in
            WorkoutDetailView(workout: workout)
        }
        .task {
            guard settingsArray.first?.healthKitEnabled == true else {
                recomputeRecovery()
                return
            }
            let hk = appServices.healthDataCache
            externalWorkouts = (try? await hk.fetchExternalWorkouts(days: 7)) ?? []
            recomputeRecovery()
        }
        .onChange(of: workouts) { recomputeRecovery() }
        .onChange(of: cardioSessions) { recomputeRecovery() }
    }

    private func recomputeRecovery() {
        recoveryResult = RecoveryEngine.evaluate(
            workouts: workouts,
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50))
        )
    }

    private func createWorkoutFromSuggestions() {
        let workout = Workout(name: suggestedWorkoutType, date: .now)
        modelContext.insert(workout)
        for (index, suggestion) in suggestedExercises.enumerated() {
            let exercise = Exercise(name: suggestion.name, workout: workout, category: suggestion.group)
            exercise.order = index
            modelContext.insert(exercise)
            workout.exercises.append(exercise)
        }
        createdWorkout = workout
    }
}

#Preview {
    NavigationStack { SmartSuggestionsView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
