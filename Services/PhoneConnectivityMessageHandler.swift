import Foundation
import SwiftData
import WatchConnectivity

// MARK: - Incoming messages & persistence

extension PhoneConnectivityManager {

    func handleIncoming(userInfo: [String: Any]) {
        guard let typeRaw = userInfo[WatchMessageKey.type] as? String,
              let type    = WatchMessageType(rawValue: typeRaw)
        else { return }

        switch type {
        case .syncWorkout:
            if let data    = userInfo[WatchMessageKey.workoutPayload] as? Data,
               let payload = try? JSONDecoder().decode(WatchWorkoutPayload.self, from: data) {
                persistWorkout(payload)
            }
        case .syncCardio:
            if let data    = userInfo[WatchMessageKey.cardioPayload] as? Data,
               let payload = try? JSONDecoder().decode(WatchCardioPayload.self, from: data) {
                persistCardio(payload)
            }
        case .finishActiveWorkout:
            finishActiveWorkout()
        default:
            break
        }

        lastSyncDate = .now
    }

    /// Watch requested we finish the phone's in-progress workout. Mirrors
    /// the local Finish path without the rating/notes prompt — those can be
    /// added later by editing the workout. HealthKit save still runs when
    /// the user has the sync toggled on.
    func finishActiveWorkout() {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Workout>(
            predicate: #Predicate { !$0.isTemplate && $0.endTime == nil },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        guard let workout = (try? ctx.fetch(descriptor))?.first else {
            publishActiveWorkout(name: nil, startedAt: nil)
            return
        }
        workout.endTime = .now
        try? ctx.save()

        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )
        publishActiveWorkout(name: nil, startedAt: nil)

        let settings = (try? ctx.fetch(FetchDescriptor<UserSettings>()))?.first
        if settings?.healthKitEnabled == true {
            Task { try? await HealthKitManager.shared.saveStrengthWorkout(workout) }
        }
    }

    func persistWorkout(_ payload: WatchWorkoutPayload) {
        guard let ctx = modelContext else { return }
        WatchPayloadPersistence.persistWorkout(payload, in: ctx)
    }

    func persistCardio(_ payload: WatchCardioPayload) {
        guard let ctx = modelContext else { return }
        WatchPayloadPersistence.persistCardio(payload, in: ctx)
    }
}
