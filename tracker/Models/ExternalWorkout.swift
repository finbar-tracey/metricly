import Foundation
import HealthKit

struct ExternalWorkout: Identifiable {
    let id: UUID
    let workoutType: HKWorkoutActivityType
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let totalCalories: Double?
    let totalDistance: Double?   // meters
    let sourceName: String

    var isFromThisApp: Bool {
        sourceName.lowercased().contains("metricly") || sourceName.lowercased().contains("tracker")
    }

    var displayName: String {
        switch workoutType {
        case .running: return "Run"
        case .cycling: return "Ride"
        case .swimming: return "Swim"
        case .walking: return "Walk"
        case .hiking: return "Hike"
        case .yoga: return "Yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .rowing: return "Row"
        case .elliptical: return "Elliptical"
        case .stairClimbing: return "Stairs"
        case .pilates: return "Pilates"
        case .dance: return "Dance"
        default: return "Workout"
        }
    }

    var icon: String {
        switch workoutType {
        case .running: return "figure.run"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell"
        case .highIntensityIntervalTraining: return "bolt.heart"
        case .rowing: return "figure.rower"
        case .elliptical: return "figure.elliptical"
        case .stairClimbing: return "figure.stair.stepper"
        case .pilates: return "figure.pilates"
        case .dance: return "figure.dance"
        default: return "figure.mixed.cardio"
        }
    }

    /// Estimated fatigue 0...1 based on duration and calorie rate
    var estimatedFatigueScore: Double {
        let durationHours = duration / 3600
        let calorieRate = (totalCalories ?? 0) / max(durationHours, 0.1)
        if calorieRate > 500 { return 0.8 }
        if calorieRate > 300 { return 0.5 }
        if durationHours > 1.5 { return 0.6 }
        return 0.3
    }
}
