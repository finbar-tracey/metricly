import XCTest
@testable import tracker

/// Round-trip tests for the Watch ↔ iPhone Codable payloads. The whole
/// reason these structs exist is to survive JSON encode + decode across
/// the WCSession boundary; if encoding then decoding doesn't produce an
/// equal value, the watch app silently shows stale or wrong data.
final class WatchSyncModelsTests: XCTestCase {

    // MARK: - Helpers

    private func roundTrip<T: Codable>(_ value: T, as _: T.Type) throws -> T {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func sampleWorkout() -> WatchWorkoutPayload {
        WatchWorkoutPayload(
            id: UUID(uuidString: "5b8a5f5e-aaaa-bbbb-cccc-111111111111")!,
            name: "Push Day",
            startDate: Date(timeIntervalSince1970: 1_700_000_000),
            endDate: Date(timeIntervalSince1970: 1_700_003_600),
            totalCalories: 245.5,
            avgHeartRate: 112,
            maxHeartRate: 165,
            exercises: [
                WatchExercisePayload(name: "Bench Press", sets: [
                    WatchSetPayload(reps: 8, weightKg: 80, isWarmUp: false),
                    WatchSetPayload(reps: 8, weightKg: 80, isWarmUp: false),
                ]),
                WatchExercisePayload(name: "Overhead Press", sets: [
                    WatchSetPayload(reps: 5, weightKg: 40, isWarmUp: true),
                    WatchSetPayload(reps: 6, weightKg: 50, isWarmUp: false),
                ]),
            ]
        )
    }

    private func sampleCardio() -> WatchCardioPayload {
        WatchCardioPayload(
            id: UUID(uuidString: "5b8a5f5e-dddd-eeee-ffff-222222222222")!,
            date: Date(timeIntervalSince1970: 1_700_004_000),
            activityTypeRaw: "outdoorRun",
            durationSeconds: 1830,
            distanceMeters: 5_120,
            avgHeartRate: 158,
            maxHeartRate: 178,
            calories: 412,
            elevationGain: 28
        )
    }

    // MARK: - Workout round trip

    func testWorkoutPayloadRoundTripPreservesAllFields() throws {
        let original = sampleWorkout()
        let decoded = try roundTrip(original, as: WatchWorkoutPayload.self)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.startDate.timeIntervalSince1970, original.startDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.endDate.timeIntervalSince1970, original.endDate.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.totalCalories, original.totalCalories)
        XCTAssertEqual(decoded.avgHeartRate, original.avgHeartRate)
        XCTAssertEqual(decoded.maxHeartRate, original.maxHeartRate)
        XCTAssertEqual(decoded.exercises.count, original.exercises.count)
    }

    func testWorkoutPayloadRoundTripPreservesExerciseOrder() throws {
        let original = sampleWorkout()
        let decoded = try roundTrip(original, as: WatchWorkoutPayload.self)

        XCTAssertEqual(decoded.exercises.map(\.name), original.exercises.map(\.name))
    }

    func testWorkoutPayloadRoundTripPreservesWarmUpFlag() throws {
        let original = sampleWorkout()
        let decoded = try roundTrip(original, as: WatchWorkoutPayload.self)

        let originalFlags = original.exercises.flatMap { $0.sets.map(\.isWarmUp) }
        let decodedFlags  = decoded.exercises.flatMap { $0.sets.map(\.isWarmUp) }
        XCTAssertEqual(decodedFlags, originalFlags)
    }

    func testWorkoutPayloadHandlesNilOptionals() throws {
        let original = WatchWorkoutPayload(
            id: UUID(),
            name: "Quick session",
            startDate: .now,
            endDate: .now.addingTimeInterval(600),
            totalCalories: nil,
            avgHeartRate: nil,
            maxHeartRate: nil,
            exercises: []
        )
        let decoded = try roundTrip(original, as: WatchWorkoutPayload.self)
        XCTAssertNil(decoded.totalCalories)
        XCTAssertNil(decoded.avgHeartRate)
        XCTAssertNil(decoded.maxHeartRate)
        XCTAssertTrue(decoded.exercises.isEmpty)
    }

    // MARK: - Cardio round trip

    func testCardioPayloadRoundTripPreservesAllFields() throws {
        let original = sampleCardio()
        let decoded = try roundTrip(original, as: WatchCardioPayload.self)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.date.timeIntervalSince1970, original.date.timeIntervalSince1970, accuracy: 0.001)
        XCTAssertEqual(decoded.activityTypeRaw, original.activityTypeRaw)
        XCTAssertEqual(decoded.durationSeconds, original.durationSeconds)
        XCTAssertEqual(decoded.distanceMeters, original.distanceMeters)
        XCTAssertEqual(decoded.avgHeartRate, original.avgHeartRate)
        XCTAssertEqual(decoded.maxHeartRate, original.maxHeartRate)
        XCTAssertEqual(decoded.calories, original.calories)
        XCTAssertEqual(decoded.elevationGain, original.elevationGain)
    }

    func testCardioPayloadHandlesNilOptionals() throws {
        let original = WatchCardioPayload(
            id: UUID(),
            date: .now,
            activityTypeRaw: "outdoorWalk",
            durationSeconds: 1200,
            distanceMeters: 1500,
            avgHeartRate: nil,
            maxHeartRate: nil,
            calories: nil,
            elevationGain: 0
        )
        let decoded = try roundTrip(original, as: WatchCardioPayload.self)
        XCTAssertNil(decoded.avgHeartRate)
        XCTAssertNil(decoded.maxHeartRate)
        XCTAssertNil(decoded.calories)
    }

    // MARK: - Activity type raw value contract

    /// The Watch sends `activityTypeRaw` as a string that the iPhone maps
    /// back to a `CardioType`. If the iPhone's enum diverges from what
    /// the Watch sends, sessions silently land with the wrong type. Pin
    /// every known raw value so a rename triggers a compile / test break.
    func testCardioTypeRawValuesAreStable() {
        // These must match the strings the Watch sends as activityTypeRaw.
        XCTAssertEqual(CardioType.outdoorRun.rawValue, "outdoorRun")
        XCTAssertEqual(CardioType.indoorRun.rawValue, "indoorRun")
        XCTAssertEqual(CardioType.outdoorWalk.rawValue, "outdoorWalk")
        XCTAssertEqual(CardioType.indoorWalk.rawValue, "indoorWalk")
        XCTAssertEqual(CardioType.outdoorCycle.rawValue, "outdoorCycle")
    }
}
