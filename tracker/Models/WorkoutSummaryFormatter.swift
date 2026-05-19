import Foundation

/// Plain-text formatter for sharing a workout. Extracted from
/// WorkoutDetailView because it's pure value logic — the view used to
/// stringify exercise rows itself, which made the view bigger without
/// any UI benefit.
enum WorkoutSummaryFormatter {

    /// "Share as Text" summary. Multi-line, emoji-decorated, suitable
    /// for copying into Messages / Notes / social.
    static func plainText(for workout: Workout, weightUnit: WeightUnit) -> String {
        var lines: [String] = []
        lines.append("💪 \(workout.name)")
        lines.append(workout.date.formatted(date: .long, time: .omitted))

        if let duration = workout.formattedDuration {
            lines.append("Duration: \(duration)")
        }
        if let rating = workout.rating, rating > 0 {
            lines.append("Rating: \(String(repeating: "⭐", count: rating))")
        }
        lines.append("")

        let sorted = workout.exercises.sorted { $0.order < $1.order }
        for exercise in sorted {
            let workingSets = exercise.sets.filter { !$0.isWarmUp }
            let warmUps = exercise.sets.filter(\.isWarmUp)

            var header = exercise.name
            if let cat = exercise.category { header += " (\(cat.rawValue))" }
            lines.append(header)

            if !warmUps.isEmpty {
                let warmUpStr = warmUps.map { "\($0.reps)×\(weightUnit.formatShort($0.weight))" }.joined(separator: ", ")
                lines.append("  Warm-up: \(warmUpStr)")
            }
            for (i, s) in workingSets.enumerated() {
                if s.isCardio {
                    let detail = [s.formattedDistance(unit: weightUnit.distanceUnit), s.formattedDuration].compactMap { $0 }.joined(separator: " in ")
                    lines.append("  Entry \(i + 1): \(detail)")
                } else {
                    lines.append("  Set \(i + 1): \(s.reps) reps × \(weightUnit.format(s.weight))")
                }
            }
            lines.append("")
        }

        if !workout.notes.isEmpty {
            lines.append("Notes: \(workout.notes)")
            lines.append("")
        }

        lines.append("Logged with Metricly")
        return lines.joined(separator: "\n")
    }
}
