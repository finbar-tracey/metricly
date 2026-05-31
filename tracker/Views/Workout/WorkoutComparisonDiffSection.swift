import SwiftUI
import SwiftData

enum WorkoutComparisonDiffSection {

    struct ExerciseMatch {
        let name: String
        let icon: String?
        let leftExercise: Exercise?
        let rightExercise: Exercise?

        var volumeDiff: Double? {
            guard let left = leftExercise, let right = rightExercise else { return nil }
            let leftVol = left.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            let rightVol = right.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            guard leftVol > 0 else { return nil }
            return ((rightVol - leftVol) / leftVol) * 100
        }
    }

    static func exerciseComparisonCard(left: Workout, right: Workout, weightUnit: WeightUnit) -> some View {
        let matched = matchExercises(left: left, right: right)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Exercises", icon: "dumbbell.fill", color: .accentColor)

            if matched.isEmpty {
                Text("No matching exercises found between these workouts.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(matched.enumerated()), id: \.element.name) { idx, match in
                        exerciseMatchRow(match, weightUnit: weightUnit)
                            .accessibilityElement(children: .combine)
                        if idx < matched.count - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .appCard()
    }

    private static func exerciseMatchRow(_ match: ExerciseMatch, weightUnit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let icon = match.icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(Color.accentColor.opacity(0.20), lineWidth: 0.5)
                            )
                        Image(systemName: icon)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(match.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                Spacer()
                if let diff = match.volumeDiff {
                    HStack(spacing: 3) {
                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%+.0f%%", diff)).font(.caption.bold().monospacedDigit())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(
                        LinearGradient(
                            colors: diff > 0 ? [.green, AppTheme.Signal.recoveryShade]
                                              : [.red, Color(red: 0.78, green: 0.20, blue: 0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: (diff > 0 ? Color.green : Color.red).opacity(0.40), radius: 4, y: 2)
                } else {
                    Text("Only in one").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                }
            }

            HStack(alignment: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 3) {
                    if let ex = match.leftExercise {
                        ForEach(Array(ex.sets.filter { !$0.isWarmUp }.enumerated()), id: \.offset) { _, s in
                            Text("\(s.reps) × \(weightUnit.formatShort(s.weight))")
                                .font(.caption.monospacedDigit()).foregroundStyle(.blue)
                        }
                    } else {
                        Text("—").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Rectangle().fill(Color(.separator)).frame(width: 1).padding(.vertical, 2).padding(.horizontal, 8)

                VStack(alignment: .trailing, spacing: 3) {
                    if let ex = match.rightExercise {
                        ForEach(Array(ex.sets.filter { !$0.isWarmUp }.enumerated()), id: \.offset) { _, s in
                            Text("\(s.reps) × \(weightUnit.formatShort(s.weight))")
                                .font(.caption.monospacedDigit()).foregroundStyle(.orange)
                        }
                    } else {
                        Text("—").font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private static func matchExercises(left: Workout, right: Workout) -> [ExerciseMatch] {
        var matches: [ExerciseMatch] = []
        var seen = Set<String>()
        let allNames = left.exercises.map(\.name) + right.exercises.map(\.name)
        for name in allNames {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            let leftEx = left.exercises.first { $0.name.lowercased() == key }
            let rightEx = right.exercises.first { $0.name.lowercased() == key }
            matches.append(ExerciseMatch(
                name: name,
                icon: (leftEx ?? rightEx)?.category?.icon,
                leftExercise: leftEx,
                rightExercise: rightEx
            ))
        }
        return matches
    }
}
