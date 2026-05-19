import SwiftUI
import SwiftData

struct SmartSuggestionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]

    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var createdWorkout: Workout?
    @State private var recoveryResult: RecoveryResult = .empty

    private func recomputeRecovery() {
        recoveryResult = RecoveryEngine.evaluate(
            workouts: workouts,
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50))
        )
    }

    private var muscleReadiness: [(MuscleGroup, Double)] {
        recoveryResult.muscleResults.map { ($0.group, $0.freshness) }.sorted { $0.1 > $1.1 }
    }

    private var readyMuscles: [MuscleGroup] {
        recoveryResult.muscleResults.filter { $0.freshness >= 0.7 }.map(\.group)
    }

    private var suggestedWorkoutType: String { recoveryResult.suggestedWorkoutType }

    private var suggestedExercises: [SuggestedExercise] {
        var suggestions: [SuggestedExercise] = []
        let recentExercises = recentExerciseNames(days: 7)
        for group in readyMuscles.prefix(4) {
            let exercises = exercisesForGroup(group)
            let fresh = exercises.filter { !recentExercises.contains($0.lowercased()) }
            let pick = fresh.first ?? exercises.first ?? group.rawValue
            suggestions.append(SuggestedExercise(name: pick, group: group, reason: reasonForGroup(group)))
        }
        return suggestions
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                if !suggestedExercises.isEmpty {
                    suggestionsCard
                }
                whyCard
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
            let hk = HealthDataCache.shared
            externalWorkouts = (try? await hk.fetchExternalWorkouts(days: 7)) ?? []
            recomputeRecovery()
        }
        .onChange(of: workouts) { recomputeRecovery() }
        .onChange(of: cardioSessions) { recomputeRecovery() }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HeroCard(palette: [
            AppTheme.Signal.focus,
            Color(red: 0.40, green: 0.40, blue: 0.92),
            AppTheme.Signal.calm
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Suggested")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(suggestedWorkoutType)
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }

                // Readiness chips
                FlowLayout(spacing: 6) {
                    ForEach(muscleReadiness, id: \.0) { group, freshness in
                        HStack(spacing: 5) {
                            Circle()
                                .fill(RecoveryEngine.freshnessColor(freshness))
                                .frame(width: 8, height: 8)
                                .shadow(color: RecoveryEngine.freshnessColor(freshness).opacity(0.6), radius: 3)
                            Text(group.rawValue)
                                .font(.caption2.weight(.semibold))
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 0.5))
                        .foregroundStyle(.white)
                    }
                }

                Text("Based on your recovery and training history")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(20)
        }
    }

    // MARK: - Suggestions Card

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Suggested Exercises", icon: "sparkles", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(suggestedExercises.enumerated()), id: \.element.id) { idx, suggestion in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.accentColor.opacity(0.12))
                                .frame(width: 38, height: 38)
                            MuscleIconView(group: suggestion.group, color: Color.accentColor)
                                .frame(width: 16, height: 16)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.name)
                                .font(.subheadline.weight(.semibold))
                            HStack(spacing: 6) {
                                Text(suggestion.group.rawValue)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7).padding(.vertical, 2)
                                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    .foregroundStyle(Color.accentColor)
                                Text(suggestion.reason)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < suggestedExercises.count - 1 {
                        Divider().padding(.leading, 68)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Button { createWorkoutFromSuggestions() } label: {
                Label("Create Workout from Suggestions", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            }
            .buttonStyle(.plain)
        }
        .appCard()
    }

    // MARK: - Why Card

    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "How It Works", icon: "info.circle.fill", color: .secondary)

            VStack(spacing: 0) {
                infoRow(icon: "heart.text.square", color: .red, text: "Muscles with 70%+ recovery are prioritized")
                Divider().padding(.leading, 50)
                infoRow(icon: "clock.arrow.circlepath", color: .orange, text: "Exercises not done in the last 7 days are preferred")
                Divider().padding(.leading, 50)
                infoRow(icon: "chart.bar", color: .blue, text: "Suggestions update as you train more")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func infoRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(text).font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Helpers

    private func recentExerciseNames(days: Int) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return Set(workouts.filter { $0.date >= cutoff }.flatMap { $0.exercises.map { $0.name.lowercased() } })
    }

    private func reasonForGroup(_ group: MuscleGroup) -> String {
        if let lastTrained = recoveryResult.muscleResults.first(where: { $0.group == group })?.lastTrained {
            let days = Int(Date.now.timeIntervalSince(lastTrained) / 86400)
            if days == 0 { return "Trained today" }
            if days == 1 { return "Last trained yesterday" }
            return "Last trained \(days) days ago"
        }
        return "Not recently trained"
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

    private func exercisesForGroup(_ group: MuscleGroup) -> [String] {
        let used = workouts.flatMap(\.exercises).filter { $0.category == group }.map(\.name)
        let unique = Array(Set(used))
        if !unique.isEmpty { return unique }
        switch group {
        case .chest: return ["Bench Press", "Dumbbell Fly", "Incline Press"]
        case .back: return ["Barbell Row", "Lat Pulldown", "Dumbbell Row"]
        case .shoulders: return ["Overhead Press", "Lateral Raise", "Face Pull"]
        case .biceps: return ["Barbell Curl", "Hammer Curl", "Preacher Curl"]
        case .triceps: return ["Tricep Pushdown", "Overhead Extension", "Skull Crusher"]
        case .legs: return ["Squat", "Romanian Deadlift", "Leg Press"]
        case .core: return ["Plank", "Cable Crunch", "Hanging Leg Raise"]
        case .cardio: return ["Running", "Cycling", "Rowing"]
        case .other: return ["Deadlift", "Farmer Walk"]
        }
    }
}

struct SuggestedExercise: Identifiable {
    let id = UUID()
    let name: String
    let group: MuscleGroup
    let reason: String
}

#Preview {
    NavigationStack { SmartSuggestionsView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
