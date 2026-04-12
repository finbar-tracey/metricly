import SwiftUI
import SwiftData
import UIKit

struct FinishWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    let workout: Workout

    @State private var rating: Int = 0
    @State private var notes: String

    init(workout: Workout) {
        self.workout = workout
        _notes = State(initialValue: workout.notes)
    }

    private var totalVolume: Double {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.reduce(0) { $0 + Double($1.reps) * $1.weight }
    }

    var body: some View {
        NavigationStack {
            Form {
                // Celebration header
                Section {
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.12))
                                .frame(width: 72, height: 72)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.green)
                        }
                        Text("Great work!")
                            .font(.title2.bold())
                        Text("How was your workout?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                        rating = value
                                    }
                                } label: {
                                    Image(systemName: value <= rating ? "star.fill" : "star")
                                        .font(.title)
                                        .foregroundStyle(value <= rating ? .yellow : .secondary)
                                        .scaleEffect(value <= rating ? 1.1 : 1.0)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                                .accessibilityAddTraits(value <= rating ? .isSelected : [])
                            }
                        }
                        if rating > 0 {
                            Text(ratingLabel)
                                .font(.caption.bold())
                                .foregroundStyle(.secondary)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .listRowBackground(Color.clear)
                }

                // Stats cards
                Section {
                    HStack(spacing: 0) {
                        finishStatCard(icon: "clock", value: workout.formattedDuration ?? "-", label: "Duration")
                        Divider().frame(height: 36)
                        finishStatCard(icon: "figure.strengthtraining.functional", value: "\(workout.exercises.count)", label: "Exercises")
                        Divider().frame(height: 36)
                        let totalSets = workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
                        finishStatCard(icon: "repeat", value: "\(totalSets)", label: "Sets")
                        Divider().frame(height: 36)
                        finishStatCard(icon: "scalemass", value: formatVolume(totalVolume), label: "Volume")
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Summary")
                }

                Section {
                    TextField("How did it feel? Any notes...", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        finishWorkout()
                    }
                    .font(.headline)
                }
            }
        }
    }

    private func finishStatCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ volumeKg: Double) -> String {
        let value = weightUnit.display(volumeKg)
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Rough session"
        case 2: return "Below average"
        case 3: return "Decent workout"
        case 4: return "Great session"
        case 5: return "Crushed it!"
        default: return ""
        }
    }

    private func finishWorkout() {
        workout.endTime = .now
        workout.notes = notes
        if rating > 0 {
            workout.rating = rating
        }

        // End Live Activity
        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )

        // Save to Apple Health if enabled
        if settingsArray.first?.healthKitEnabled == true {
            Task {
                try? await HealthKitManager.shared.saveWorkout(
                    name: workout.name,
                    start: workout.date,
                    end: workout.endTime ?? .now
                )
            }
        }

        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        dismiss()
    }
}
