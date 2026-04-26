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

    private var totalSets: Int {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.sectionSpacing) {
                    celebrationCard
                    statsCard
                    notesCard
                }
                .padding(.horizontal)
                .padding(.bottom, 36)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Finish Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finishWorkout() }
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Celebration hero card

    private var celebrationCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.green, Color(red: 0.1, green: 0.72, blue: 0.35).opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 200)
                .offset(x: 170, y: -60)

            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 56, height: 56)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Great work!")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(workout.name)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                            .lineLimit(1)
                    }
                }

                // Star rating
                VStack(alignment: .leading, spacing: 8) {
                    Text("How was it?")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))

                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    rating = value
                                }
                            } label: {
                                Image(systemName: value <= rating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundStyle(value <= rating ? .yellow : .white.opacity(0.50))
                                    .scaleEffect(value <= rating ? 1.15 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                            .accessibilityAddTraits(value <= rating ? .isSelected : [])
                        }

                        if rating > 0 {
                            Text(ratingLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Summary", icon: "chart.bar.fill", color: .accentColor)

            HStack(spacing: 0) {
                finishStat(icon: "clock", value: workout.formattedDuration ?? "-", label: "Duration", color: .orange)
                Divider().frame(height: 50)
                finishStat(icon: "figure.strengthtraining.functional", value: "\(workout.exercises.count)", label: "Exercises", color: .accentColor)
                Divider().frame(height: 50)
                finishStat(icon: "repeat", value: "\(totalSets)", label: "Sets", color: .purple)
                Divider().frame(height: 50)
                finishStat(icon: "scalemass", value: formatVolume(totalVolume), label: "Volume", color: .green)
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 3)
        }
    }

    private func finishStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Notes card

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Notes", icon: "note.text", color: .secondary)

            TextField("How did it feel? Any notes...", text: $notes, axis: .vertical)
                .lineLimit(3...6)
                .font(.subheadline)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    // MARK: - Helpers

    private func formatVolume(_ volumeKg: Double) -> String {
        let value = weightUnit.display(volumeKg)
        if value >= 1000 {
            return String(format: "%.1fk", value / 1000)
        }
        return String(format: "%.0f", value)
    }

    private var ratingLabel: String {
        switch rating {
        case 1: return "Rough"
        case 2: return "Okay"
        case 3: return "Decent"
        case 4: return "Great"
        case 5: return "Crushed it!"
        default: return ""
        }
    }

    private func finishWorkout() {
        workout.endTime = .now
        workout.notes = notes
        if rating > 0 { workout.rating = rating }

        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )

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
