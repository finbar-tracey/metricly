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
        case .back: return "figure.rowing"
        case .shoulders: return "figure.arms.open"
        case .biceps: return "figure.strengthtraining.functional"
        case .triceps: return "figure.strengthtraining.functional"
        case .legs: return "figure.walk"
        case .core: return "figure.core.training"
        case .cardio: return "figure.run"
        case .other: return "dumbbell"
        }
    }
}

@Model
final class Exercise {
    var name: String
    var notes: String = ""
    var order: Int = 0
    var supersetGroup: Int? = nil
    var categoryRaw: String? = nil
    var customRestDuration: Int? = nil
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var sets: [ExerciseSet]

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
