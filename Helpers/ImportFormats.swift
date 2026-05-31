import Foundation

// MARK: - Format-agnostic intermediate representation

struct ParsedWorkout: Equatable {
    var title: String
    var startDate: Date
    var endDate: Date?
    var notes: String
    var exercises: [ParsedExercise]
}

struct ParsedExercise: Equatable {
    var name: String
    var supersetGroup: Int?
    var notes: String
    var sets: [ParsedSet]
}

struct ParsedSet: Equatable {
    var reps: Int
    var weightKg: Double
    var rpe: Int?
    var isWarmUp: Bool
    var distanceMeters: Double?
    var durationSeconds: Int?
}

// MARK: - Format detection

enum ImportFormat: Equatable {
    case metricly
    case strong
    case hevy

    static func detect(header: [String]) -> ImportFormat? {
        let normalized = Set(header.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        })

        if normalized.contains("weight_kg") &&
           normalized.contains("exercise_title") {
            return .hevy
        }

        if normalized.contains("set order") &&
           normalized.contains("workout name") {
            return .strong
        }

        if header.count >= 10,
           header[0].lowercased().contains("date"),
           header[1].lowercased().contains("workout"),
           header[8].lowercased().contains("reps"),
           header[9].lowercased().contains("weight") {
            return .metricly
        }

        return nil
    }
}
