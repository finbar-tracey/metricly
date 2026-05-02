import Foundation

// MARK: - Shared Watch ↔ iPhone sync models
//
// This file is compiled into BOTH the tracker (iPhone) and MetriclyWatch targets.
// Keep it pure Foundation — no SwiftUI, no HealthKit, no SwiftData.

// MARK: - Completed workout payload (Watch → iPhone)

struct WatchWorkoutPayload: Codable {
    let id           : UUID
    let name         : String
    let startDate    : Date
    let endDate      : Date
    let totalCalories: Double?
    let avgHeartRate : Double?
    let maxHeartRate : Double?
    let exercises    : [WatchExercisePayload]
}

struct WatchExercisePayload: Codable {
    let name: String
    let sets: [WatchSetPayload]
}

struct WatchSetPayload: Codable {
    let reps    : Int
    let weightKg: Double
    let isWarmUp: Bool
}

// MARK: - Completed cardio payload (Watch → iPhone)

struct WatchCardioPayload: Codable {
    let id             : UUID
    let date           : Date
    let activityTypeRaw: String   // matches CardioType.rawValue on iPhone
    let durationSeconds: Double
    let distanceMeters : Double
    let avgHeartRate   : Double?
    let maxHeartRate   : Double?
    let calories       : Double?
    let elevationGain  : Double
}

// MARK: - WCSession message keys & types

enum WatchMessageKey {
    static let type           = "type"
    static let workoutPayload = "workoutPayload"
    static let cardioPayload  = "cardioPayload"
    static let exerciseList   = "exerciseList"
    static let todayPlan      = "todayPlan"
    static let useKilograms   = "useKilograms"
    static let currentStreak  = "currentStreak"
    static let requestExercises = "requestExercises"
}

enum WatchMessageType: String {
    case syncWorkout  = "syncWorkout"
    case syncCardio   = "syncCardio"
    case exerciseData = "exerciseData"
    case requestData  = "requestData"
}
