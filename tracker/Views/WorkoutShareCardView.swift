import SwiftUI

struct WorkoutShareCardView: View {
    let workout: Workout
    let weightUnit: WeightUnit

    private var sortedExercises: [Exercise] {
        workout.exercises.sorted { $0.order < $1.order }
    }

    private var totalVolume: Double {
        workout.exercises.reduce(0) { total, exercise in
            total + exercise.sets.filter { !$0.isWarmUp }.reduce(0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    private var totalSets: Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
    }

    private var muscleGroups: [MuscleGroup] {
        let groups = Set(workout.exercises.compactMap(\.category))
        return Array(groups).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2)
                    Text(workout.name)
                        .font(.title2.bold())
                    Spacer()
                    if let rating = workout.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.yellow)
                    }
                }

                HStack(spacing: 12) {
                    Label {
                        Text(workout.date, format: .dateTime.weekday(.wide).month().day())
                    } icon: {
                        Image(systemName: "calendar")
                    }
                    .font(.subheadline)

                    if let duration = workout.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.subheadline)
                    }
                    Spacer()
                }
                .foregroundStyle(.secondary)
            }
            .padding(20)
            .background(Color.accentColor.opacity(0.1))

            // Stats bar
            HStack(spacing: 0) {
                statItem(value: "\(workout.exercises.count)", label: "Exercises")
                Divider().frame(height: 36)
                statItem(value: "\(totalSets)", label: "Sets")
                Divider().frame(height: 36)
                statItem(value: weightUnit.formatShort(totalVolume), label: "Volume")
            }
            .padding(.vertical, 12)
            .background(Color(.systemBackground))

            Divider()

            // Exercises list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(sortedExercises.prefix(8)) { exercise in
                    HStack {
                        Image(systemName: exercise.category?.icon ?? "dumbbell")
                            .foregroundStyle(.tint)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline.bold())
                            let workingSets = exercise.sets.filter { !$0.isWarmUp }
                            if !workingSets.isEmpty {
                                Text(workingSets.map { "\($0.reps)×\(weightUnit.formatShort($0.weight))" }.joined(separator: "  "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if exercise.supersetGroup != nil {
                            Text("SS")
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.tint.opacity(0.15), in: .capsule)
                        }
                    }
                }

                if sortedExercises.count > 8 {
                    Text("+\(sortedExercises.count - 8) more exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(20)

            // Muscle groups
            if !muscleGroups.isEmpty {
                Divider()
                HStack(spacing: 8) {
                    ForEach(muscleGroups) { group in
                        Text(group.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: .capsule)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            // Footer
            Divider()
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                Text("Metricly")
                    .font(.caption.bold())
                Spacer()
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Image Rendering

extension WorkoutShareCardView {
    @MainActor
    func renderImage() -> UIImage? {
        let renderer = ImageRenderer(content:
            self
                .frame(width: 380)
                .padding(16)
                .background(Color(.systemGroupedBackground))
        )
        renderer.scale = 3.0
        return renderer.uiImage
    }
}
