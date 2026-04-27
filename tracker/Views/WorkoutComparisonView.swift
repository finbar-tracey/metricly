import SwiftUI
import SwiftData

struct WorkoutComparisonView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    @State private var leftWorkout: Workout?
    @State private var rightWorkout: Workout?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                pickerCard

                if let left = leftWorkout, let right = rightWorkout {
                    comparisonHeroCard(left: left, right: right)
                    summaryCard(left: left, right: right)
                    exerciseComparisonCard(left: left, right: right)
                } else {
                    emptyStateCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Picker Card

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Select Workouts", icon: "arrow.left.arrow.right", color: .accentColor)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.12)).frame(width: 34, height: 34)
                        Text("A").font(.system(size: 14, weight: .black)).foregroundStyle(.blue)
                    }
                    Picker("First", selection: $leftWorkout) {
                        Text("Select workout…").tag(nil as Workout?)
                        ForEach(workouts) { w in Text(workoutLabel(w)).tag(w as Workout?) }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)

                Divider().padding(.leading, 62)

                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.orange.opacity(0.12)).frame(width: 34, height: 34)
                        Text("B").font(.system(size: 14, weight: .black)).foregroundStyle(.orange)
                    }
                    Picker("Second", selection: $rightWorkout) {
                        Text("Select workout…").tag(nil as Workout?)
                        ForEach(workouts) { w in Text(workoutLabel(w)).tag(w as Workout?) }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Comparison Hero Card

    private func comparisonHeroCard(left: Workout, right: Workout) -> some View {
        let leftVol = volume(left)
        let rightVol = volume(right)
        let volDiff = leftVol > 0 ? ((rightVol - leftVol) / leftVol) * 100 : 0
        let bIsAhead = rightVol > leftVol

        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [bIsAhead ? Color.orange : Color.blue,
                         bIsAhead ? Color.red.opacity(0.6) : Color.cyan.opacity(0.6)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Volume Comparison")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Image(systemName: bIsAhead ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 20, weight: .bold))
                            Text(String(format: "%+.1f%%", volDiff))
                                .font(.system(size: 32, weight: .black, design: .rounded)).monospacedDigit()
                        }
                        .foregroundStyle(.white)
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    heroSideCol(label: left.name, date: left.date, value: formatVolume(leftVol), color: .blue, tag: "A")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 44)
                    heroSideCol(label: right.name, date: right.date, value: formatVolume(rightVol), color: .orange, tag: "B")
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroSideCol(label: String, date: Date, value: String, color: Color, tag: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Text(tag)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.white.opacity(0.25), in: Capsule())
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
            }
            Text(date, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption2).foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Summary Card

    private func summaryCard(left: Workout, right: Workout) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Summary", icon: "list.bullet.rectangle", color: .accentColor)
                Spacer()
                HStack(spacing: 8) {
                    Text("A").font(.caption2.bold()).foregroundStyle(.blue)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.blue.opacity(0.12), in: Capsule())
                    Text("vs").font(.caption2).foregroundStyle(.secondary)
                    Text("B").font(.caption2.bold()).foregroundStyle(.orange)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12), in: Capsule())
                }
            }

            VStack(spacing: 0) {
                summaryRow(label: "Exercises",
                           left: "\(left.exercises.count)", right: "\(right.exercises.count)",
                           leftNum: Double(left.exercises.count), rightNum: Double(right.exercises.count))
                Divider().padding(.leading, 16)
                summaryRow(label: "Total Sets",
                           left: "\(totalSets(left))", right: "\(totalSets(right))",
                           leftNum: Double(totalSets(left)), rightNum: Double(totalSets(right)))
                Divider().padding(.leading, 16)
                summaryRow(label: "Volume",
                           left: formatVolume(volume(left)), right: formatVolume(volume(right)),
                           leftNum: volume(left), rightNum: volume(right))
                if let ld = left.formattedDuration, let rd = right.formattedDuration,
                   let ls = left.endTime.map({ $0.timeIntervalSince(left.date) }),
                   let rs = right.endTime.map({ $0.timeIntervalSince(right.date) }) {
                    Divider().padding(.leading, 16)
                    summaryRow(label: "Duration", left: ld, right: rd, leftNum: ls, rightNum: rs)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func summaryRow(label: String, left: String, right: String, leftNum: Double, rightNum: Double) -> some View {
        HStack(spacing: 8) {
            Text(left)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(leftNum >= rightNum ? Color.blue : Color.blue.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                if abs(leftNum - rightNum) > 0.001 {
                    Image(systemName: leftNum > rightNum ? "a.circle.fill" : "b.circle.fill")
                        .font(.system(size: 10)).foregroundStyle(leftNum > rightNum ? .blue : .orange)
                }
            }
            .frame(maxWidth: .infinity)

            Text(right)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(rightNum >= leftNum ? Color.orange : Color.orange.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Exercise Comparison Card

    private func exerciseComparisonCard(left: Workout, right: Workout) -> some View {
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
                        exerciseMatchRow(match)
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

    private func exerciseMatchRow(_ match: ExerciseMatch) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                if let icon = match.icon {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(0.12))
                            .frame(width: 28, height: 28)
                        Image(systemName: icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                Text(match.name).font(.subheadline.weight(.semibold))
                Spacer()
                if let diff = match.volumeDiff {
                    HStack(spacing: 3) {
                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text(String(format: "%+.0f%%", diff)).font(.caption.bold().monospacedDigit())
                    }
                    .foregroundStyle(diff > 0 ? .green : .red)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background((diff > 0 ? Color.green : Color.red).opacity(0.10), in: Capsule())
                } else {
                    Text("Only in one").font(.caption2).foregroundStyle(.secondary)
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

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("Pick Two Workouts").font(.headline)
                Text("Select a workout A and workout B above to compare them side by side.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Helpers

    private func workoutLabel(_ workout: Workout) -> String {
        "\(workout.name) — \(workout.date.formatted(.dateTime.month(.abbreviated).day().year()))"
    }

    private func totalSets(_ workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
    }

    private func volume(_ workout: Workout) -> Double {
        workout.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    private func formatVolume(_ volumeKg: Double) -> String {
        let displayValue = weightUnit.display(volumeKg)
        if displayValue >= 1000 { return String(format: "%.1fk %@", displayValue / 1000, weightUnit.label) }
        return String(format: "%.0f %@", displayValue, weightUnit.label)
    }

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

    private func matchExercises(left: Workout, right: Workout) -> [ExerciseMatch] {
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
