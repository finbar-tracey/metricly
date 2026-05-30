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
            // Gradient hero header — bold, branded, white-on-gradient to
            // match the app's hero language (ImageRenderer-safe: solid
            // colours / gradients only, no materials).
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.title2.bold())
                        .foregroundStyle(.white.opacity(0.9))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(workout.name)
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        HStack(spacing: 10) {
                            Label {
                                Text(workout.date, format: .dateTime.weekday(.wide).month().day())
                            } icon: {
                                Image(systemName: "calendar")
                            }
                            if let duration = workout.formattedDuration {
                                Label(duration, systemImage: "clock")
                            }
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.82))
                    }
                    Spacer(minLength: 8)
                    if let rating = workout.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill").font(.caption2)
                            }
                        }
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    statItem(value: "\(workout.exercises.count)", label: "Exercises")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    statItem(value: "\(totalSets)", label: "Sets")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    statItem(value: weightUnit.formatShort(totalVolume), label: "Volume")
                }
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 0.5)
                )
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.80)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            // Exercises list
            VStack(alignment: .leading, spacing: 10) {
                ForEach(sortedExercises.prefix(8)) { exercise in
                    HStack {
                        Group {
                            if let category = exercise.category {
                                MuscleIconView(group: category, color: Color.accentColor)
                            } else {
                                Image(systemName: "dumbbell").foregroundStyle(.tint)
                            }
                        }.frame(width: 14, height: 14)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.subheadline.bold())
                            let workingSets = exercise.sets.filter { !$0.isWarmUp }
                            if !workingSets.isEmpty {
                                Text(workingSets.map { s in
                                    var text = "\(s.reps)×\(weightUnit.formatShort(s.weight))"
                                    if let rpe = s.rpe { text += " @\(rpe)" }
                                    return text
                                }.joined(separator: "  "))
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

            // Footer — branded (this card gets posted publicly)
            Divider()
            HStack(spacing: 5) {
                Image(systemName: "dumbbell.fill")
                    .font(.caption.bold())
                    .foregroundStyle(Color.accentColor)
                Text("Metricly")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Spacer()
                Text("Trained with Metricly")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
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
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
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
