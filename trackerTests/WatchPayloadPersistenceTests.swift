import XCTest
import SwiftData
@testable import tracker

@MainActor
final class WatchPayloadPersistenceTests: XCTestCase {

    func testPersistWorkoutRoundTrip() throws {
        let container = try ModelContainer(for: Workout.self, Exercise.self, ExerciseSet.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let payload = WatchWorkoutPayload(
            id: UUID(),
            name: "Watch Push",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            totalCalories: nil,
            avgHeartRate: nil,
            maxHeartRate: nil,
            exercises: [
                WatchExercisePayload(
                    name: "Bench",
                    sets: [WatchSetPayload(reps: 8, weightKg: 60, isWarmUp: false)]
                ),
            ]
        )
        WatchPayloadPersistence.persistWorkout(payload, in: ctx)
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].name, "Watch Push")
        XCTAssertEqual(workouts[0].exercises.count, 1)
        XCTAssertEqual(workouts[0].exercises[0].sets.count, 1)
        XCTAssertEqual(workouts[0].exercises[0].sets[0].reps, 8)
    }

    func testPersistCardioRoundTrip() throws {
        let container = try ModelContainer(for: CardioSession.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let payload = WatchCardioPayload(
            id: UUID(),
            date: Date(timeIntervalSince1970: 3_000),
            activityTypeRaw: CardioType.outdoorRun.rawValue,
            durationSeconds: 1800,
            distanceMeters: 5000,
            avgHeartRate: 150,
            maxHeartRate: 170,
            calories: 320,
            elevationGain: 42
        )
        WatchPayloadPersistence.persistCardio(payload, in: ctx)
        let sessions = try ctx.fetch(FetchDescriptor<CardioSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].distanceMeters, 5000, accuracy: 0.01)
        XCTAssertEqual(sessions[0].avgHeartRate, 150)
    }
}
