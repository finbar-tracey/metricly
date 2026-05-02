import SwiftUI

// MARK: - Shareable workout summary card

struct WorkoutShareCard: View {
    let workout: Workout
    let weightUnit: WeightUnit

    private var totalVolume: Double {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.reduce(0) { $0 + Double($1.reps) * $1.weight }
    }

    private var totalSets: Int {
        workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    private var formattedVolume: String {
        let v = weightUnit.display(totalVolume)
        if v >= 1000 { return String(format: "%.1fk %@", v / 1000, weightUnit.rawValue) }
        return String(format: "%.0f %@", v, weightUnit.rawValue)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Background gradient
            LinearGradient(
                colors: [Color(red: 1.0, green: 0.52, blue: 0.15),
                         Color(red: 0.88, green: 0.22, blue: 0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Decorative circles
            Circle().fill(.white.opacity(0.06)).frame(width: 220).offset(x: 240, y: -80)
            Circle().fill(.white.opacity(0.04)).frame(width: 140).offset(x: 280, y: 100)

            VStack(alignment: .leading, spacing: 18) {

                // ── Header ───────────────────────────────────────────────────
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 48, height: 48)
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Strength Training")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.75))
                        Text(workout.date, format: .dateTime.weekday(.wide).month(.abbreviated).day().year())
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Text("Metricly")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(.white.opacity(0.15), in: Capsule())
                }

                // ── Workout name ─────────────────────────────────────────────
                Text(workout.name)
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                // ── Stats strip ──────────────────────────────────────────────
                HStack(spacing: 0) {
                    shareStatCol(label: "Duration",  value: workout.formattedDuration ?? "--")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    shareStatCol(label: "Exercises", value: "\(workout.exercises.count)")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    shareStatCol(label: "Sets",      value: "\(totalSets)")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    shareStatCol(label: "Volume",    value: formattedVolume)
                }
                .padding(.vertical, 12)
                .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))

                // ── Top exercises ────────────────────────────────────────────
                let topExercises = Array(workout.exercises
                    .filter { !$0.sets.isEmpty }
                    .prefix(3))
                if !topExercises.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(topExercises) { ex in
                            Text(ex.name)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(.white.opacity(0.15), in: Capsule())
                        }
                        if workout.exercises.count > 3 {
                            Text("+\(workout.exercises.count - 3) more")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(22)
        }
        .frame(width: 380, height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func shareStatCol(label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Render helper

@MainActor
func renderWorkoutShareImage(workout: Workout, weightUnit: WeightUnit) -> UIImage? {
    let card = WorkoutShareCard(workout: workout, weightUnit: weightUnit)
    let renderer = ImageRenderer(content: card)
    renderer.scale = 3
    return renderer.uiImage
}
