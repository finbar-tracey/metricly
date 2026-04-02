import SwiftUI
import SwiftData

struct MuscleRecoveryView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    // Standard recovery hours per muscle group
    private let recoveryHours: [MuscleGroup: Double] = [
        .chest: 48,
        .back: 48,
        .shoulders: 48,
        .biceps: 36,
        .triceps: 36,
        .legs: 72,
        .core: 24,
        .cardio: 24,
        .other: 48
    ]

    private var muscleStates: [MuscleState] {
        let trainable = MuscleGroup.allCases.filter { $0 != .cardio && $0 != .other }
        return trainable.map { group in
            let lastTrained = lastTrainedDate(for: group)
            let recoveryTime = recoveryHours[group] ?? 48
            let freshness = calculateFreshness(lastTrained: lastTrained, recoveryHours: recoveryTime)
            return MuscleState(
                group: group,
                lastTrained: lastTrained,
                recoveryHours: recoveryTime,
                freshness: freshness
            )
        }
        .sorted { $0.freshness > $1.freshness }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Muscle Readiness")
                        .font(.headline)
                    Text("Based on your recent workouts and standard recovery windows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    readinessOverview
                }
                .padding(.vertical, 4)
            }

            Section("By Muscle Group") {
                ForEach(muscleStates) { state in
                    muscleRow(state)
                }
            }

            Section("Suggested Today") {
                let ready = muscleStates.filter { $0.freshness >= 0.8 }
                if ready.isEmpty {
                    Text("All muscles are still recovering. Consider a rest day or light cardio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ready) { state in
                        Label(state.group.rawValue, systemImage: state.group.icon)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("Recovery")
    }

    private var readinessOverview: some View {
        let avgFreshness = muscleStates.isEmpty ? 0 : muscleStates.map(\.freshness).reduce(0, +) / Double(muscleStates.count)
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: avgFreshness)
                    .stroke(freshnessColor(avgFreshness), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(avgFreshness * 100))")
                        .font(.title.bold())
                    Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Readiness")
                    .font(.subheadline.bold())
                Text(readinessLabel(avgFreshness))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func muscleRow(_ state: MuscleState) -> some View {
        HStack(spacing: 14) {
            Image(systemName: state.group.icon)
                .font(.title3)
                .foregroundStyle(freshnessColor(state.freshness))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(state.group.rawValue)
                    .font(.subheadline.weight(.medium))

                ProgressView(value: state.freshness)
                    .tint(freshnessColor(state.freshness))

                if let last = state.lastTrained {
                    Text(timeAgoText(from: last))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not trained recently")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(freshnessLabel(state.freshness))
                .font(.caption.bold())
                .foregroundStyle(freshnessColor(state.freshness))
        }
        .padding(.vertical, 2)
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
        guard let lastTrained else { return 1.0 } // Never trained = fully fresh
        let hoursSince = Date.now.timeIntervalSince(lastTrained) / 3600
        return min(1.0, max(0.0, hoursSince / recoveryHours))
    }

    private func freshnessColor(_ freshness: Double) -> Color {
        if freshness >= 0.8 { return .green }
        if freshness >= 0.5 { return .yellow }
        if freshness >= 0.25 { return .orange }
        return .red
    }

    private func freshnessLabel(_ freshness: Double) -> String {
        if freshness >= 0.8 { return "Ready" }
        if freshness >= 0.5 { return "Almost" }
        if freshness >= 0.25 { return "Recovering" }
        return "Fatigued"
    }

    private func readinessLabel(_ freshness: Double) -> String {
        if freshness >= 0.8 { return "You're well recovered. Great time for a hard session!" }
        if freshness >= 0.5 { return "Mostly recovered. Light to moderate training recommended." }
        if freshness >= 0.25 { return "Still recovering. Consider lighter work or different muscles." }
        return "Significant fatigue. A rest day would be beneficial."
    }

    private func timeAgoText(from date: Date) -> String {
        let hours = Int(Date.now.timeIntervalSince(date) / 3600)
        if hours < 1 { return "Just now" }
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}

struct MuscleState: Identifiable {
    let id = UUID()
    let group: MuscleGroup
    let lastTrained: Date?
    let recoveryHours: Double
    let freshness: Double
}

#Preview {
    NavigationStack {
        MuscleRecoveryView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
