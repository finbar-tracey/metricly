import SwiftUI

struct ExerciseHeaderStrip: View {
    let exercise: Exercise
    let prWeight: Double
    let activeGoal: LiftGoal?
    let weightUnit: WeightUnit

    var body: some View {
        HStack(spacing: 8) {
            if prWeight > 0 {
                statPill(
                    icon: "trophy.fill",
                    iconColor: AppTheme.Signal.amber,
                    label: "PR",
                    value: weightUnit.formatShort(prWeight)
                )
            }

            if let goal = activeGoal {
                let currentBest = max(prWeight, exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0)
                let pct = goal.targetWeight > 0 ? min(1.0, currentBest / goal.targetWeight) : 0
                statPill(
                    icon: "target",
                    iconColor: Color.accentColor,
                    label: "Goal",
                    value: "\(weightUnit.formatShort(goal.targetWeight)) · \(Int(pct * 100))%"
                )
            }

            if let cat = exercise.category {
                statPill(
                    icon: cat.icon,
                    iconColor: .purple,
                    label: nil,
                    value: cat.rawValue
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }

    private func statPill(icon: String, iconColor: Color, label: String?, value: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(iconColor)
            if let label {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(0.4)
            }
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemFill), in: Capsule())
    }
}
