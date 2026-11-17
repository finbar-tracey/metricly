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
            lastSyncDate = .now
        default:
            lastSyncDate = .now
        }
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
        do { try ctx.save() } catch {
            AppErrorBus.shared.report(message: "Couldn't save the finished workout.")
        }

        let totalSets = workout.exercises.flatMap(\.sets).count
        WorkoutActivityManager.shared.endActivity(
            exerciseCount: workout.exercises.count,
            setCount: totalSets
        )
        publishActiveWorkout(name: nil, startedAt: nil)

        let settings = (try? ctx.fetch(FetchDescriptor<UserSettings>()))?.first
        if settings?.healthKitEnabled == true {
            Task {
                do { try await HealthKitManager.shared.saveStrengthWorkout(workout) }
                catch { AppErrorBus.shared.report(message: "Couldn't save workout to Apple Health.") }
            }
        }
    }

    func persistWorkout(_ payload: WatchWorkoutPayload) {
        guard let ctx = modelContext else {
            pendingWorkoutPayloads.append(payload)
            return
        }
        if WatchPayloadPersistence.persistWorkout(payload, in: ctx) {
            lastSyncDate = .now
        } else {
            pendingWorkoutPayloads.append(payload)
        }
    }

    func persistCardio(_ payload: WatchCardioPayload) {
        guard let ctx = modelContext else {
            pendingCardioPayloads.append(payload)
            return
        }
        if WatchPayloadPersistence.persistCardio(payload, in: ctx) {
            lastSyncDate = .now
        } else {
            pendingCardioPayloads.append(payload)
        }
    }

    /// Persist payloads that arrived before `modelContext` was set (or
    /// whose save failed). Safe to call repeatedly; dedup is by sourceID.
    func drainPendingPayloads() {
        guard let ctx = modelContext else { return }
        let workouts = pendingWorkoutPayloads
        let cardio = pendingCardioPayloads
        pendingWorkoutPayloads = []
        pendingCardioPayloads = []
        var persistedAny = false
        for p in workouts {
            if WatchPayloadPersistence.persistWorkout(p, in: ctx) { persistedAny = true }
            else { pendingWorkoutPayloads.append(p) }
        }
        for p in cardio {
            if WatchPayloadPersistence.persistCardio(p, in: ctx) { persistedAny = true }
            else { pendingCardioPayloads.append(p) }
        }
        // Only a payload that actually landed counts as a sync.
        if persistedAny { lastSyncDate = .now }
    }
}
