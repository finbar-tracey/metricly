import SwiftUI
import SwiftData

struct SmartSuggestionsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    private let recoveryHours: [MuscleGroup: Double] = [
        .chest: 48, .back: 48, .shoulders: 48,
        .biceps: 36, .triceps: 36, .legs: 72,
        .core: 24, .cardio: 24, .other: 48
    ]

    private var muscleReadiness: [(MuscleGroup, Double)] {
        let trainable = MuscleGroup.allCases.filter { $0 != .cardio && $0 != .other }
        return trainable.map { group in
            let lastTrained = lastTrainedDate(for: group)
            let recovery = recoveryHours[group] ?? 48
            let freshness = calculateFreshness(lastTrained: lastTrained, recoveryHours: recovery)
            return (group, freshness)
        }
        .sorted { $0.1 > $1.1 }
    }

    private var readyMuscles: [MuscleGroup] {
        muscleReadiness.filter { $0.1 >= 0.7 }.map(\.0)
    }

    private var suggestedWorkoutType: String {
        let ready = Set(readyMuscles)
        if ready.contains(.chest) && ready.contains(.shoulders) && ready.contains(.triceps) {
            return "Push"
        } else if ready.contains(.back) && ready.contains(.biceps) {
            return "Pull"
        } else if ready.contains(.legs) {
            return "Legs"
        } else if ready.count >= 3 {
            return "Full Body"
        } else {
            return "Active Recovery"
        }
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
                                    .fill(freshnessColor(freshness))
                                    .frame(width: 8, height: 8)
                                Text(group.rawValue)
                                    .font(.caption2)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(freshnessColor(freshness).opacity(0.1), in: Capsule())
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

    private func lastTrainedDate(for group: MuscleGroup) -> Date? {
        for workout in workouts {
            for exercise in workout.exercises {
                if exercise.category == group && !exercise.sets.isEmpty {
                    return workout.date
                }
            }
        }
        return nil
    }

    private func calculateFreshness(lastTrained: Date?, recoveryHours: Double) -> Double {
        guard let lastTrained else { return 1.0 }
        let hoursSince = Date.now.timeIntervalSince(lastTrained) / 3600
        return min(1.0, max(0.0, hoursSince / recoveryHours))
    }

    private func freshnessColor(_ freshness: Double) -> Color {
        if freshness >= 0.8 { return .green }
        if freshness >= 0.5 { return .yellow }
        if freshness >= 0.25 { return .orange }
        return .red
    }

    private func recentExerciseNames(days: Int) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        let recent = workouts.filter { $0.date >= cutoff }
        return Set(recent.flatMap { $0.exercises.map { $0.name.lowercased() } })
    }

    private func reasonForGroup(_ group: MuscleGroup) -> String {
        if let lastTrained = lastTrainedDate(for: group) {
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

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

#Preview {
    NavigationStack {
        SmartSuggestionsView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
