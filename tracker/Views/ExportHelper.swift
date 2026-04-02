import Foundation

struct ExportHelper {
    static func generateCSV(workouts: [Workout]) -> String {
        var csv = "Date,Workout,Rating,Duration (min),Exercise,Muscle Group,Superset Group,Set,Reps,Weight (kg),RPE\n"
        for workout in workouts.sorted(by: { $0.date > $1.date }) {
            let dateStr = formatDate(workout.date)
            let durationMin = workout.duration.map { String(Int($0 / 60)) } ?? ""
            let ratingStr = workout.rating.map(String.init) ?? ""
            for exercise in workout.exercises.sorted(by: { $0.order < $1.order }) {
                let ssGroup = exercise.supersetGroup.map(String.init) ?? ""
                let categoryStr = exercise.category?.rawValue ?? ""
                for (index, set) in exercise.sets.enumerated() {
                    let rpeStr = set.rpe.map(String.init) ?? ""
                    let line = "\(dateStr),\(escape(workout.name)),\(ratingStr),\(durationMin),\(escape(exercise.name)),\(categoryStr),\(ssGroup),\(index + 1),\(set.reps),\(String(format: "%.1f", set.weight)),\(rpeStr)\n"
                    csv += line
                }
            }
        }
        return csv
    }

    private static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
