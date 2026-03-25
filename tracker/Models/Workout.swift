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
}
