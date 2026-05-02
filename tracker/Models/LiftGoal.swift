import Foundation
import SwiftData

@Model
final class LiftGoal {
    var exerciseName: String = ""
    var targetWeight: Double = 0 // Stored in kg
    var createdDate: Date = Date()
    var achievedDate: Date? = nil

    init(exerciseName: String, targetWeight: Double, createdDate: Date = .now) {
        self.exerciseName = exerciseName
        self.targetWeight = targetWeight
        self.createdDate = createdDate
    }
}
