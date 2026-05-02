import Foundation
import SwiftData

@Model
final class TrainingProgram {
    var name: String = ""
    var totalWeeks: Int = 0
    var currentWeek: Int = 1
    var startDate: Date = Date()
    var isActive: Bool = true
    var notes: String = ""
    @Relationship(deleteRule: .cascade, inverse: \ProgramDay.program)
    var _days: [ProgramDay]? = nil

    /// Non-optional accessor — CloudKit requires the stored relationship be optional.
    var days: [ProgramDay] {
        get { _days ?? [] }
        set { _days = newValue }
    }

    init(name: String, totalWeeks: Int, startDate: Date = .now) {
        self.name = name
        self.totalWeeks = totalWeeks
        self.startDate = startDate
        self.currentWeek = 1
        self.isActive = true
        self.notes = ""
        self.days = []
    }

    var progress: Double {
        guard totalWeeks > 0 else { return 0 }
        return min(1.0, Double(currentWeek - 1) / Double(totalWeeks))
    }

    var formattedProgress: String {
        "Week \(currentWeek) of \(totalWeeks)"
    }
}

@Model
final class ProgramDay {
    var dayOfWeek: Int = 1 // 1 = Sunday, 7 = Saturday
    var workoutName: String = ""
    var order: Int = 0
    var program: TrainingProgram?
    @Relationship(deleteRule: .cascade, inverse: \ProgramExercise.day)
    var _exercises: [ProgramExercise]? = nil

    /// Non-optional accessor — CloudKit requires the stored relationship be optional.
    var exercises: [ProgramExercise] {
        get { _exercises ?? [] }
        set { _exercises = newValue }
    }

    init(dayOfWeek: Int, workoutName: String, program: TrainingProgram? = nil) {
        self.dayOfWeek = dayOfWeek
        self.workoutName = workoutName
        self.order = 0
        self.program = program
        self.exercises = []
    }

    var dayName: String {
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "?" }
        return names[dayOfWeek]
    }

    var fullDayName: String {
        let names = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard dayOfWeek >= 1 && dayOfWeek <= 7 else { return "?" }
        return names[dayOfWeek]
    }
}

@Model
final class ProgramExercise {
    var name: String = ""
    var targetSets: Int = 3
    var targetReps: String = "8-12" // e.g. "8-12" or "5"
    var categoryRaw: String? = nil
    var order: Int = 0
    var day: ProgramDay?

    var category: MuscleGroup? {
        get { categoryRaw.flatMap { MuscleGroup(rawValue: $0) } }
        set { categoryRaw = newValue?.rawValue }
    }

    init(name: String, targetSets: Int = 3, targetReps: String = "8-12", category: MuscleGroup? = nil) {
        self.name = name
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.categoryRaw = category?.rawValue
        self.order = 0
    }
}
