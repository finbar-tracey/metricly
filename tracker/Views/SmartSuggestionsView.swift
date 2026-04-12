import SwiftUI
import SwiftData

struct SmartSuggestionsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    private var recoveryResult: RecoveryResult {
        RecoveryEngine.evaluate(workouts: workouts)
    }

    private var muscleReadiness: [(MuscleGroup, Double)] {
        recoveryResult.muscleResults.map { ($0.group, $0.freshness) }
            .sorted { $0.1 > $1.1 }
    }

    private var readyMuscles: [MuscleGroup] {
        recoveryResult.muscleResults.filter { $0.freshness >= 0.7 }.map(\.group)
    }

    private var suggestedWorkoutType: String {
        recoveryResult.suggestedWorkoutType
    }

    private var suggestedExercises: [SuggestedExercise] {
        var suggestions: [SuggestedExercise] = []
        let recentExercises = recentExerciseNames(days: 7)

        for group in readyMuscles.prefix(4) {
            let exercises = exercisesForGroup(group)
            // Prefer exercises not done recently
            let fresh = exercises.filter { !recentExercises.contains($0.lowercased()) }
            let pick = fresh.first ?? exercises.first ?? group.rawValue
            suggestions.append(SuggestedExercise(name: pick, group: group, reason: reasonForGroup(group)))
        }

        return suggestions
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .font(.title2)
                            .foregroundStyle(.tint)
                        VStack(alignment: .leading) {
                            Text("Suggested: \(suggestedWorkoutType)")
                                .font(.headline)
                            Text("Based on your recovery and training history")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Ready muscles chips
                    FlowLayout(spacing: 6) {
                        ForEach(muscleReadiness, id: \.0) { group, freshness in
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(RecoveryEngine.freshnessColor(freshness))
                                    .frame(width: 8, height: 8)
                                Text(group.rawValue)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(RecoveryEngine.freshnessColor(freshness).opacity(0.1), in: Capsule())
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            if !suggestedExercises.isEmpty {
                Section("Suggested Exercises") {
                    ForEach(suggestedExercises) { suggestion in
                        HStack(spacing: 14) {
                            Image(systemName: suggestion.group.icon)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.name)
                                    .font(.subheadline.weight(.medium))
                                HStack(spacing: 4) {
                                    Text(suggestion.group.rawValue)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color(.systemFill), in: .capsule)
                                    Text(suggestion.reason)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Why These?") {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(icon: "heart.text.square", text: "Muscles with 70%+ recovery are prioritized")
                    infoRow(icon: "clock.arrow.circlepath", text: "Exercises not done in the last 7 days are preferred")
                    infoRow(icon: "chart.bar", text: "Suggestions update as you train")
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Smart Suggestions")
    }

    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func recentExerciseNames(days: Int) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let recent = workouts.filter { $0.date >= cutoff }
        return Set(recent.flatMap { $0.exercises.map { $0.name.lowercased() } })
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

    private func exercisesForGroup(_ group: MuscleGroup) -> [String] {
        // Return historically used exercises for this muscle group
        let used = workouts.flatMap(\.exercises)
            .filter { $0.category == group }
            .map(\.name)
        let unique = Array(Set(used))
        if !unique.isEmpty { return unique }

        // Fallback defaults
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
    NavigationStack {
        SmartSuggestionsView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
