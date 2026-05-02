import Foundation
import SwiftData

@Model
final class ExerciseSet {
    var reps: Int = 0
    var weight: Double = 0
    var isWarmUp: Bool = false
    var rpe: Int? = nil
    var distance: Double? = nil       // km
    var durationSeconds: Int? = nil   // seconds
    var exercise: Exercise?

    var isCardio: Bool {
        distance != nil || durationSeconds != nil
    }

    var formattedDuration: String? {
        guard let seconds = durationSeconds else { return nil }
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    var formattedDistance: String? {
        formattedDistance(unit: .km)
    }

    func formattedDistance(unit: DistanceUnit) -> String? {
        guard let km = distance else { return nil }
        return unit.format(km)
    }

    init(reps: Int = 0, weight: Double = 0, isWarmUp: Bool = false, rpe: Int? = nil,
         distance: Double? = nil, durationSeconds: Int? = nil, exercise: Exercise? = nil) {
        self.reps = reps
        self.weight = weight
        self.isWarmUp = isWarmUp
        self.rpe = rpe
        self.distance = distance
        self.durationSeconds = durationSeconds
        self.exercise = exercise
    }
}
