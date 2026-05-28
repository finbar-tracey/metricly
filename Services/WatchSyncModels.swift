import Foundation

// MARK: - Shared Watch ↔ iPhone sync models
//
// This file is compiled into BOTH the tracker (iPhone) and MetriclyWatch targets.
// Keep it pure Foundation — no SwiftUI, no HealthKit, no SwiftData.

// MARK: - Completed workout payload (Watch → iPhone)
//
// All four payload structs are `Sendable` because they cross actor
// boundaries: the watch encodes them inside the `WCSessionDelegate`'s
// nonisolated callback, then `Task { @MainActor in … }` hops the
// decoded value to the main actor for SwiftData persistence. Without
// `Sendable` conformance, Swift 6 strict-concurrency mode rejects the
// capture. These are pure value types over Sendable primitives so the
// conformance is trivially derivable — no synthesised lock required.

nonisolated struct WatchWorkoutPayload: Codable, Sendable {
    let id           : UUID
    let name         : String
    let startDate    : Date
    let endDate      : Date
    let totalCalories: Double?
    let avgHeartRate : Double?
    let maxHeartRate : Double?
    let exercises    : [WatchExercisePayload]
}

nonisolated struct WatchExercisePayload: Codable, Sendable {
    let name: String
    let sets: [WatchSetPayload]
}

nonisolated struct WatchSetPayload: Codable, Sendable {
    let reps    : Int
    let weightKg: Double
    let isWarmUp: Bool
}

// MARK: - Completed cardio payload (Watch → iPhone)

nonisolated struct WatchCardioPayload: Codable, Sendable {
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
//
// Marked `nonisolated` so the iPhone target's default-MainActor
// isolation (SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor) doesn't push
// these constant strings onto the main actor. WCSession's delegate
// callbacks run in a nonisolated context and need to read these keys
// to dispatch incoming messages — without this, Swift 6 strict mode
// rejects the read.

nonisolated enum WatchMessageKey {
    static let type           = "type"
    static let workoutPayload = "workoutPayload"
    static let cardioPayload  = "cardioPayload"
    static let exerciseList   = "exerciseList"
    static let todayPlan      = "todayPlan"
    /// Names of the exercises in today's most-recent matching workout, in order.
    /// Used by the Watch to pre-populate the exercise list on Start Gym so users
    /// don't begin from an empty session.
    static let todayExercises = "todayExercises"
    static let useKilograms   = "useKilograms"
    static let currentStreak  = "currentStreak"
    /// Engine-recommended workout name for today (may differ from the
    /// schedule if the adaptive plan adjusted it).
    static let adaptivePlanName     = "adaptivePlanName"
    /// `TodayPlan.Intensity.rawValue` — rest/light/moderate/hard.
    static let adaptiveIntensity    = "adaptiveIntensity"
    /// First reason from the plan's reason list, for the watch UI to
    /// show a one-liner ("Recovery is low (32%)" etc.).
    static let adaptiveTopReason    = "adaptiveTopReason"
    static let requestExercises = "requestExercises"
    /// Map of exercise name → rest seconds. iPhone pushes the user's
    /// per-exercise rest overrides so the Watch's rest timer respects them.
    static let perExerciseRest = "perExerciseRest"
    /// Global rest-timer fallback (seconds). iPhone publishes the user's
    /// `UserSettings.defaultRestDuration` so the Watch's `restDuration(for:)`
    /// helper has a sane non-default when there's no per-exercise override.
    /// Without this the Watch was permanently stuck at 60s regardless of
    /// what the user picked in the phone's settings.
    static let restDuration    = "restDuration"
    /// In-progress workout state. iPhone publishes these when a workout
    /// starts/finishes on the phone so the Watch and its complications
    /// can show "In Progress · <name>" without local participation.
    static let activeStartedAt = "activeStartedAt"     // Double, seconds since 1970
    static let activeName      = "activeName"          // String
}

nonisolated enum WatchMessageType: String {
    case syncWorkout  = "syncWorkout"
    case syncCardio   = "syncCardio"
    case exerciseData = "exerciseData"
    case requestData  = "requestData"
    /// Watch asking iPhone to end its currently-active workout. Used when
    /// the user wants to "take over" mid-session — drop the phone, finish
    /// from the wrist.
    case finishActiveWorkout = "finishActiveWorkout"
}
