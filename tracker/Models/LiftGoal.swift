import Foundation
import SwiftData

@Model
final class LiftGoal {
    var exerciseName: String
    var targetWeight: Double // Stored in kg
    var createdDate: Date
    var achievedDate: Date?

    init(exerciseName: String, targetWeight: Double, createdDate: Date = .now) {
        self.exerciseName = exerciseName
        self.targetWeight = targetWeight
        self.createdDate = createdDate
    }
}
