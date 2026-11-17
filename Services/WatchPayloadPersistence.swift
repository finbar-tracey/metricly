import Foundation
import SwiftData

/// Persists Watch-originated workout / cardio payloads into SwiftData.
enum WatchPayloadPersistence {

    /// Persist a watch workout. Returns false on save failure (also
    /// reported via `AppErrorBus`); true when saved or already present.
    @MainActor
    @discardableResult
    static func persistWorkout(_ payload: WatchWorkoutPayload, in context: ModelContext) -> Bool {
        let id = payload.id
        let existing = (try? context.fetchCount(FetchDescriptor<Workout>(
            predicate: #Predicate { $0.sourceID == id }
        ))) ?? 0
        guard existing == 0 else { return true }

        let workout = Workout(name: payload.name, date: payload.startDate)
        workout.endTime = payload.endDate
        workout.sourceID = id
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
        return save(context, what: "workout", undo: workout)
    }

    @MainActor
    @discardableResult
    static func persistCardio(_ payload: WatchCardioPayload, in context: ModelContext) -> Bool {
        let id = payload.id
        let existing = (try? context.fetchCount(FetchDescriptor<CardioSession>(
            predicate: #Predicate { $0.sourceID == id }
        ))) ?? 0
        guard existing == 0 else { return true }

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
        session.sourceID = id
        context.insert(session)
        return save(context, what: "cardio session", undo: session)
    }

    @MainActor
    private static func save(_ context: ModelContext, what: String, undo: any PersistentModel) -> Bool {
        do {
            try context.save()
            return true
        } catch {
            // Remove the unsaved insert (not a full rollback, which could
            // discard unrelated pending edits) so a retry doesn't duplicate.
            context.delete(undo)
            AppErrorBus.shared.report(
                message: "Couldn't save your Apple Watch \(what). It will be retried."
            )
            return false
        }
    }
}

/// Disk-backed copy of watch payloads that haven't reached SwiftData yet.
/// WCSession drops a userInfo transfer once it is delivered, so an in-memory
/// queue alone loses the workout if the app is killed before the save lands.
enum PendingWatchPayloadStore {

    struct Snapshot: Codable {
        var workouts: [WatchWorkoutPayload] = []
        var cardio: [WatchCardioPayload] = []
    }

    private static var fileURL: URL? {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("pending-watch-payloads.json")
    }

    static func load() -> Snapshot {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
        else { return Snapshot() }
        return snapshot
    }

    /// Writes the queue, or removes the file when nothing is pending.
    static func save(_ snapshot: Snapshot) {
        guard let url = fileURL else { return }
        if snapshot.workouts.isEmpty && snapshot.cardio.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(snapshot).write(to: url, options: .atomic)
        } catch {
            AppErrorBus.shared.report(message: "Couldn't queue a Watch workout for retry.")
        }
    }
}
