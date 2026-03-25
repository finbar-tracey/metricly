import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var reps: Int
    var weight: Double
    var isWarmUp: Bool = false
    var exercise: Exercise?

    init(reps: Int, weight: Double, isWarmUp: Bool = false, exercise: Exercise? = nil) {
        self.reps = reps
        self.weight = weight
        self.isWarmUp = isWarmUp
        self.exercise = exercise
    }
}
