import Foundation
import SwiftData

@Model
final class Workout {
    var name: String
    var date: Date
    var isTemplate: Bool = false
    var notes: String = ""
    var rating: Int? = nil
    var startTime: Date? = nil
    var endTime: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var exercises: [Exercise]

    init(name: String, date: Date = .now, isTemplate: Bool = false) {
        self.name = name
        self.date = date
        self.isTemplate = isTemplate
        self.notes = ""
        self.startTime = isTemplate ? nil : date
        self.endTime = nil
        self.exercises = []
    }

    var duration: TimeInterval? {
        guard let start = startTime else { return nil }
        let end = endTime ?? .now
        return end.timeIntervalSince(start)
    }

    var formattedDuration: String? {
        guard let duration else { return nil }
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    var isFinished: Bool {
        endTime != nil
    }

    /// Calculate the current consecutive-day workout streak.
    static func currentStreak(from workouts: [Workout]) -> Int {
        let calendar = Calendar.current
        let workoutDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        guard !workoutDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        // If no workout today, start checking from yesterday
        if !workoutDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }
}
