import SwiftUI

struct WorkoutCardView: View {
    let workout: Workout

    private var accentColor: Color { workout.isFinished ? .green : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(workout.name)
                        .font(.system(.subheadline, design: .rounded, weight: .semibold))
                        .lineLimit(1)

                    HStack(spacing: 10) {
                        Label(
                            workout.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                            systemImage: "calendar"
                        )
                        if let duration = workout.formattedDuration {
                            Label(duration, systemImage: "clock")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                if !workout.isFinished {
                    Text("Active")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(accentColor.opacity(0.12))
                        .foregroundStyle(accentColor)
                        .clipShape(Capsule())
                } else if let rating = workout.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                        }
                    }
                    .foregroundStyle(.yellow)
                }
            }

            if !workout.exercises.isEmpty {
                HStack(spacing: 6) {
                    ForEach(workout.exercises.sorted { $0.order < $1.order }.prefix(3)) { exercise in
                        Text(exercise.name)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(accentColor)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(accentColor.opacity(0.10))
                        .clipShape(Capsule())
                    }
                    if workout.exercises.count > 3 {
                        Text("+\(workout.exercises.count - 3)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.leading, 10)
        .padding(.trailing, 2)
        .background(
            LinearGradient(
                colors: [accentColor.opacity(0.07), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 10)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor.gradient)
                .frame(width: 3)
        }
    }
}
