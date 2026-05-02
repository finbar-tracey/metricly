import Foundation
import SwiftData

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.curling"
        case .triceps: return "figure.highintensity.intervaltraining"
        case .legs: return "figure.step.training"
        case .core: return "figure.core.training"
        case .cardio: return "figure.run"
        case .other: return "dumbbell"
        }
    }
}

@Model
final class Exercise {
    var name: String = ""
    var notes: String = ""
    var order: Int = 0
    var supersetGroup: Int? = nil
    var categoryRaw: String? = nil
    var customRestDuration: Int? = nil
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var _sets: [ExerciseSet]? = nil

    /// Non-optional accessor — CloudKit requires the stored relationship be optional.
    var sets: [ExerciseSet] {
        get { _sets ?? [] }
        set { _sets = newValue }
    }

    var category: MuscleGroup? {
        get { categoryRaw.flatMap { MuscleGroup(rawValue: $0) } }
        set { categoryRaw = newValue?.rawValue }
    }

    init(name: String, workout: Workout? = nil, category: MuscleGroup? = nil) {
        self.name = name
        self.notes = ""
        self.order = 0
        self.supersetGroup = nil
        self.categoryRaw = category?.rawValue
        self.workout = workout
        self.sets = []
    }
}
