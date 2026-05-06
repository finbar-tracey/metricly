import SwiftUI

struct WorkoutCardView: View {
    let workout: Workout

    private var accentColor: Color { workout.isFinished ? .green : .accentColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                        .shadow(color: accentColor.opacity(0.4), radius: 5, y: 2)
                } else if let rating = workout.rating, rating > 0 {
                    HStack(spacing: 2) {
                        ForEach(1...rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                        }
                    }
                    .foregroundStyle(.yellow)
                }
            }

            if !workout.exercises.isEmpty {
                HStack(spacing: 6) {
                    ForEach(workout.exercises.sorted { $0.order < $1.order }.prefix(3)) { exercise in
                        Text(exercise.name)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(accentColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(accentColor.opacity(0.14))
                            .clipShape(Capsule())
                    }
                    if workout.exercises.count > 3 {
                        Text("+\(workout.exercises.count - 3)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .background(
            LinearGradient(
                colors: [accentColor.opacity(0.10), .clear],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(
                    LinearGradient(
                        colors: [accentColor, accentColor.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 4)
                .shadow(color: accentColor.opacity(0.4), radius: 4, x: 0, y: 0)
        }
    }
}
