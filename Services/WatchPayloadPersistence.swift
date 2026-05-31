import Foundation
import SwiftData

/// Persists Watch-originated workout / cardio payloads into SwiftData.
enum WatchPayloadPersistence {

    @MainActor
    static func persistWorkout(_ payload: WatchWorkoutPayload, in context: ModelContext) {
        let workout = Workout(name: payload.name, date: payload.startDate)
        workout.endTime = payload.endDate
        context.insert(workout)

        for (order, ex) in payload.exercises.enumerated() {
            let exercise = Exercise(name: ex.name, workout: workout)
            exercise.order = order
            context.insert(exercise)
            workout.exercises.append(exercise)

            for setPayload in ex.sets {
                let set = ExerciseSet(
                    reps: setPayload.reps,
                    weight: setPayload.weightKg,
                    isWarmUp: setPayload.isWarmUp,
                    exercise: exercise
                )
                context.insert(set)
                exercise.sets.append(set)
            }
        }
        try? context.save()
    }

    @MainActor
    static func persistCardio(_ payload: WatchCardioPayload, in context: ModelContext) {
        let session = CardioSession(
            date: payload.date,
            title: payload.activityTypeRaw,
            type: CardioType(rawValue: payload.activityTypeRaw) ?? .outdoorRun,
            durationSeconds: payload.durationSeconds,
            distanceMeters: payload.distanceMeters,
            elevationGainMeters: payload.elevationGain
        )
        session.avgHeartRate = payload.avgHeartRate
        session.maxHeartRate = payload.maxHeartRate
        session.caloriesBurned = payload.calories
        context.insert(session)
        try? context.save()
    }
}
