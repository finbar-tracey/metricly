import SwiftUI
import SwiftData

struct WorkoutComparisonView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    @State private var leftWorkout: Workout?
    @State private var rightWorkout: Workout?

    var body: some View {
        List {
            Section {
                workoutPicker(label: "First", selection: $leftWorkout)
                workoutPicker(label: "Second", selection: $rightWorkout)
            } header: {
                Text("Select Workouts")
            }

            if let left = leftWorkout, let right = rightWorkout {
                summarySection(left: left, right: right)
                exerciseComparisonSection(left: left, right: right)
            } else {
                Section {
                    Text("Pick two workouts above to compare them side by side.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 30)
                }
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func workoutPicker(label: String, selection: Binding<Workout?>) -> some View {
        Picker(label, selection: selection) {
            Text("Select...").tag(nil as Workout?)
            ForEach(workouts) { workout in
                Text(workoutLabel(workout)).tag(workout as Workout?)
            }
        }
    }

    private func workoutLabel(_ workout: Workout) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(workout.name) (\(formatter.string(from: workout.date)))"
    }

    // MARK: - Summary

    private func summarySection(left: Workout, right: Workout) -> some View {
        Section {
            compareRow(
                label: "Exercises",
                leftValue: "\(left.exercises.count)",
                rightValue: "\(right.exercises.count)"
            )
            compareRow(
                label: "Total Sets",
                leftValue: "\(totalSets(left))",
                rightValue: "\(totalSets(right))"
            )
            compareRow(
                label: "Volume",
                leftValue: formatVolume(volume(left)),
                rightValue: formatVolume(volume(right))
            )
            if let ld = left.formattedDuration, let rd = right.formattedDuration {
                compareRow(
                    label: "Duration",
                    leftValue: ld,
                    rightValue: rd
                )
            }
        } header: {
            HStack {
                Text("Summary")
                Spacer()
                headerLabels(left: left, right: right)
            }
        }
    }

    private func headerLabels(left: Workout, right: Workout) -> some View {
        HStack(spacing: 8) {
            let formatter: DateFormatter = {
                let f = DateFormatter()
                f.dateFormat = "MMM d"
                return f
            }()
            Text(formatter.string(from: left.date))
                .font(.caption2.bold())
                .foregroundStyle(.blue)

            Text("vs")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text(formatter.string(from: right.date))
                .font(.caption2.bold())
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Exercise Comparison

    private func exerciseComparisonSection(left: Workout, right: Workout) -> some View {
        let matched = matchExercises(left: left, right: right)
        return Section {
            if matched.isEmpty {
                Text("No matching exercises found between these workouts.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(matched, id: \.name) { match in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            if let icon = match.icon {
                                Image(systemName: icon)
                                    .foregroundStyle(.tint)
                            }
                            Text(match.name)
                                .font(.headline)
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                if let ex = match.leftExercise {
                                    ForEach(Array(ex.sets.filter { !$0.isWarmUp }.enumerated()), id: \.offset) { i, s in
                                        Text("\(s.reps)x\(weightUnit.formatShort(s.weight))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.blue)
                                    }
                                } else {
                                    Text("—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)

                            VStack(spacing: 2) {
                                let diff = match.volumeDiff
                                if let diff, abs(diff) > 0.01 {
                                    HStack(spacing: 2) {
                                        Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                                            .imageScale(.small)
                                        Text(String(format: "%+.0f%%", diff))
                                    }
                                    .font(.caption2.bold())
                                    .foregroundStyle(diff > 0 ? .green : .red)
                                } else {
                                    Text("=")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            VStack(alignment: .trailing, spacing: 4) {
                                if let ex = match.rightExercise {
                                    ForEach(Array(ex.sets.filter { !$0.isWarmUp }.enumerated()), id: \.offset) { i, s in
                                        Text("\(s.reps)x\(weightUnit.formatShort(s.weight))")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(.orange)
                                    }
                                } else {
                                    Text("—")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                }
            }
        } header: {
            Text("Exercise Comparison")
        }
    }

    // MARK: - Helpers

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
        if displayValue >= 1000 {
            return String(format: "%.1fk %@", displayValue / 1000, weightUnit.label)
        }
        return String(format: "%.0f %@", displayValue, weightUnit.label)
    }

    private func compareRow(label: String, leftValue: String, rightValue: String) -> some View {
        HStack {
            Text(leftValue)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            Text(rightValue)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
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

        // Get all exercise names from both workouts
        let allNames = (left.exercises.map(\.name) + right.exercises.map(\.name))

        for name in allNames {
            let key = name.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)

            let leftEx = left.exercises.first { $0.name.lowercased() == key }
            let rightEx = right.exercises.first { $0.name.lowercased() == key }
            let icon = (leftEx ?? rightEx)?.category?.icon

            matches.append(ExerciseMatch(
                name: name,
                icon: icon,
                leftExercise: leftEx,
                rightExercise: rightEx
            ))
        }

        return matches
    }
}
