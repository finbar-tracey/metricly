import Foundation
import SwiftData

@Model
final class Workout {
    var name: String = ""
    var date: Date = Date()
    var isTemplate: Bool = false
    var notes: String = ""
    var rating: Int? = nil
    var startTime: Date? = nil
    var endTime: Date? = nil
    @Relationship(deleteRule: .cascade, inverse: \Exercise.workout)
    var _exercises: [Exercise]? = nil

    /// Non-optional accessor — CloudKit requires the stored relationship be optional.
    var exercises: [Exercise] {
        get { _exercises ?? [] }
        set { _exercises = newValue }
    }

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

    /// Total lifted volume in kg, optionally excluding warm-up sets.
    func totalVolumeKg(excludingWarmUps: Bool = true) -> Double {
        exercises.reduce(0.0) { total, ex in
            let sets = excludingWarmUps ? ex.sets.filter { !$0.isWarmUp } : ex.sets
            return total + sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    /// Copies exercises (and their metadata) from `source` into this workout.
    /// Call after inserting the workout into the model context.
    func copyExercises(from source: [Exercise], into context: ModelContext) {
        for (index, src) in source.sorted(by: { $0.order < $1.order }).enumerated() {
            let ex = Exercise(name: src.name, workout: self, category: src.category)
            ex.order = index
            ex.notes = src.notes
            ex.supersetGroup = src.supersetGroup
            ex.customRestDuration = src.customRestDuration
            context.insert(ex)
            exercises.append(ex)
        }
    }

    /// Calculate the current consecutive-day activity streak.
    /// Cardio sessions count as active days alongside strength workouts.
    static func currentStreak(from workouts: [Workout], cardioSessions: [CardioSession] = []) -> Int {
        let calendar = Calendar.current
        var activeDays = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        activeDays.formUnion(cardioSessions.map { calendar.startOfDay(for: $0.date) })
        guard !activeDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        // If nothing active today, start checking from yesterday
        if !activeDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while activeDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }
}
