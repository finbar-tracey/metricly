import SwiftUI
import UIKit

struct FinishWorkoutSheet: View {
    @Environment(\.dismiss) private var dismiss
    let workout: Workout

    @State private var rating: Int = 0
    @State private var notes: String

    init(workout: Workout) {
        self.workout = workout
        _notes = State(initialValue: workout.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Text("How was your workout?")
                            .font(.headline)
                        HStack(spacing: 16) {
                            ForEach(1...5, id: \.self) { value in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        rating = value
                                    }
                                } label: {
                                    Image(systemName: value <= rating ? "star.fill" : "star")
                                        .font(.title)
                                        .foregroundStyle(value <= rating ? .yellow : .secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                                .accessibilityAddTraits(value <= rating ? .isSelected : [])
                            }
                        }
                        if rating > 0 {
                            Text(ratingLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section {
                    if let duration = workout.formattedDuration {
                        HStack {
                            Label("Duration", systemImage: "clock")
                            Spacer()
                            Text(duration)
                                .foregroundStyle(.secondary)
                        }
                    }
                    HStack {
                        Label("Exercises", systemImage: "figure.strengthtraining.functional")
                        Spacer()
                        Text("\(workout.exercises.count)")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Label("Total Sets", systemImage: "repeat")
                        Spacer()
                        let totalSets = workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
                        Text("\(totalSets)")
                            .foregroundStyle(.secondary)
                    }
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
                }
            }
        }
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
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        dismiss()
    }
}
