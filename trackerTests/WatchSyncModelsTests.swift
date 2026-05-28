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
    /// back to a `CardioType` via `CardioType(rawValue:)`. If either side's
    /// strings drift, sessions silently land with the wrong type (or fall
    /// back to .outdoorRun). The contract is the literal display string —
    /// `CardioType.rawValue` on iPhone equals `WatchCardioType.payloadRaw`
    /// on the watch. Pin both so a rename on either side triggers a
    /// compile / test break.
    func testCardioTypeRawValuesAreStable() {
        XCTAssertEqual(CardioType.outdoorRun.rawValue, "Outdoor Run")
        XCTAssertEqual(CardioType.indoorRun.rawValue, "Indoor Run")
        XCTAssertEqual(CardioType.outdoorWalk.rawValue, "Outdoor Walk")
        XCTAssertEqual(CardioType.indoorWalk.rawValue, "Indoor Walk")
        XCTAssertEqual(CardioType.outdoorCycle.rawValue, "Outdoor Cycle")

        // Round-trip: every string the watch is capable of producing must
        // parse back into a CardioType on iPhone. Catches the case where
        // someone renames a CardioType case without touching the watch.
        let watchSendValues = ["Outdoor Run", "Indoor Run",
                               "Outdoor Walk", "Indoor Walk", "Outdoor Cycle"]
        for raw in watchSendValues {
            XCTAssertNotNil(CardioType(rawValue: raw),
                            "Watch sends \"\(raw)\" but iPhone can't decode it")
        }
    }

    // MARK: - Adaptive plan key contract
    //
    // The phone writes `WatchMessageKey.adaptivePlanName` /
    // `adaptiveIntensity` / `adaptiveTopReason` to the WCSession
    // application context, and the complication reads them straight
    // from the App Group under the literal strings
    // `watch.adaptivePlanName` / `watch.adaptiveIntensity` /
    // `watch.adaptiveTopReason`. Both the WCSession-key literals and
    // the App-Group-key literals are spread across three targets
    // (tracker, MetriclyWatch, MetriclyWatchComplications), and a
    // rename in any one of them compiles cleanly but silently breaks
    // the watch face's adaptive plan display.
    //
    // Pin them — when these tests fail, the engineer renaming a key
    // gets a compile-time prompt that they need to update every site.

    func testAdaptivePlanMessageKeyLiteralsAreStable() {
        XCTAssertEqual(WatchMessageKey.adaptivePlanName,  "adaptivePlanName")
        XCTAssertEqual(WatchMessageKey.adaptiveIntensity, "adaptiveIntensity")
        XCTAssertEqual(WatchMessageKey.adaptiveTopReason, "adaptiveTopReason")
    }

    func testAdaptivePlanIntensityRawValuesMatchEngine() {
        // The watch displays the intensity via `TodayPlan.Intensity.rawValue`
        // (the phone writes `plan.intensity.rawValue` into the context).
        // The complication and watch UI switch on the literal strings
        // "rest" / "light" / "moderate" / "hard" — pin both sides.
        XCTAssertEqual(TodayPlan.Intensity.rest.rawValue,     "rest")
        XCTAssertEqual(TodayPlan.Intensity.light.rawValue,    "light")
        XCTAssertEqual(TodayPlan.Intensity.moderate.rawValue, "moderate")
        XCTAssertEqual(TodayPlan.Intensity.hard.rawValue,     "hard")
    }
}
