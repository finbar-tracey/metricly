import SwiftUI

struct WorkoutCardView: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(workout.isFinished ? Color.green : Color.accentColor)
                .frame(width: 4, height: 44)
                .padding(.trailing, 12)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(workout.name)
                        .font(.headline)
                    Spacer()
                    if !workout.isFinished {
                        Text("In Progress")
                            .font(.caption2.bold())
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.accentColor.opacity(0.12), in: .capsule)
                    }
                }

                HStack(spacing: 8) {
                    Label(workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                          systemImage: "calendar")
                    if let duration = workout.formattedDuration {
                        Label(duration, systemImage: "clock")
                    }
                    if let rating = workout.rating, rating > 0 {
                        HStack(spacing: 1) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .imageScale(.small)
                            }
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !workout.exercises.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(workout.exercises.sorted { $0.order < $1.order }.prefix(3)) { exercise in
                            HStack(spacing: 3) {
                                Image(systemName: exercise.category?.icon ?? "dumbbell")
                                    .font(.system(size: 9))
                                Text(exercise.name)
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(.tertiarySystemFill), in: .capsule)
                        }
                        if workout.exercises.count > 3 {
                            Text("+\(workout.exercises.count - 3)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
