import SwiftUI

/// One exercise row inside WorkoutDetailView's list. Pure presentation:
/// progress badge + RPE are precomputed by the parent (which owns the
/// cross-workout history fetch) and passed in.
struct WorkoutExerciseRow: View {
    let exercise: Exercise
    let weightUnit: WeightUnit
    /// Average RPE across working sets, nil if no RPE recorded.
    let averageRPE: Double?
    /// Progress-vs-last-session badge text + tint. nil for no change.
    let badge: Badge?

    struct Badge {
        let text: String
        let color: Color
    }

    var body: some View {
        HStack(spacing: 12) {
            if exercise.supersetGroup != nil {
                supersetIndicator
            }
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.20), lineWidth: 0.5)
                    )
                MuscleIconView(group: exercise.category ?? .other, color: Color.accentColor)
                    .frame(width: 22, height: 22)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    if exercise.supersetGroup != nil {
                        Text("SS")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.14), in: .capsule)
                    }
                }
                HStack(spacing: 8) {
                    if !exercise.sets.isEmpty {
                        let working = exercise.sets.filter { !$0.isWarmUp }
                        let warmUps = exercise.sets.filter(\.isWarmUp)
                        Text("\(working.count) sets")
                            .font(.caption).foregroundStyle(.secondary)
                        if !warmUps.isEmpty {
                            Text("+ \(warmUps.count)W")
                                .font(.caption).foregroundStyle(.orange)
                        }
                        if let best = working.map(\.weight).max(), best > 0 {
                            Text("· \(weightUnit.formatShort(best))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if let avgRPE = averageRPE {
                            Text("RPE \(String(format: "%.0f", avgRPE))")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(.purple.opacity(0.12), in: .capsule)
                        }
                    } else {
                        Text("No sets yet")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    if let cat = exercise.category {
                        Text(cat.rawValue)
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                if !exercise.notes.isEmpty {
                    Text(exercise.notes)
                        .font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }
            }
            Spacer()

            if let badge {
                Text(badge.text)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(badge.color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(badge.color.opacity(0.14), in: .capsule)
            }
        }
        .padding(.vertical, 4)
    }

    private var supersetIndicator: some View {
        let color = supersetColor(for: exercise.supersetGroup ?? 0)
        return RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: 5)
            .shadow(color: color.opacity(0.45), radius: 4, x: 0, y: 0)
            .padding(.trailing, 10)
            .padding(.vertical, -4)
    }

    private func supersetColor(for group: Int) -> Color {
        let colors: [Color] = [.purple, .blue, .cyan, .indigo, .pink]
        return colors[(group - 1) % colors.count]
    }
}
