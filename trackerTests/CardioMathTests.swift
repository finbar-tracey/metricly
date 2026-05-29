import XCTest
@testable import tracker

final class CardioMathTests: XCTestCase {

    // MARK: - CardioSplit pace

    func testKmPaceForOneKmInFiveMinutes() {
        let split = CardioSplit(
            id: 1,
            splitDistanceMeters: 1000,
            cumulativeDistanceMeters: 1000,
            durationSeconds: 5 * 60,
            cumulativeDurationSeconds: 5 * 60,
            avgHeartRate: nil
        )
        XCTAssertEqual(split.paceSecondsPerKm, 300, accuracy: 0.001)
    }

    func testMilePaceForOneKmInFiveMinutes() {
        // 5 min/km converts to ~8:02/mile
        let split = CardioSplit(
            id: 1,
            splitDistanceMeters: 1000,
            cumulativeDistanceMeters: 1000,
            durationSeconds: 5 * 60,
            cumulativeDurationSeconds: 5 * 60,
            avgHeartRate: nil
        )
        // 1 km ≈ 0.621 miles → 5 min / 0.621 mi ≈ 8.05 min/mi
        let pacePerMile = split.paceSecondsPerMile
        XCTAssertEqual(pacePerMile, 482.8, accuracy: 1.0)
    }

    func testZeroDistanceProducesZeroPace() {
        let split = CardioSplit(
            id: 1, splitDistanceMeters: 0,
            cumulativeDistanceMeters: 0, durationSeconds: 60,
            cumulativeDurationSeconds: 60, avgHeartRate: nil
        )
        XCTAssertEqual(split.paceSecondsPerKm, 0)
        XCTAssertEqual(split.paceSecondsPerMile, 0)
    }

    func testFormattedPaceProducesMinSecFormat() {
        let split = CardioSplit(
            id: 1, splitDistanceMeters: 1000,
            cumulativeDistanceMeters: 1000, durationSeconds: 330,
            cumulativeDurationSeconds: 330, avgHeartRate: nil
        )
        XCTAssertEqual(split.formattedPace(useKm: true), "5:30")
    }

    func testFormattedPaceShowsDashesForZero() {
        let split = CardioSplit(
            id: 1, splitDistanceMeters: 0,
            cumulativeDistanceMeters: 0, durationSeconds: 0,
            cumulativeDurationSeconds: 0, avgHeartRate: nil
        )
        XCTAssertEqual(split.formattedPace(useKm: true), "--:--")
    }

    func testFormattedDurationOnSplit() {
        let split = CardioSplit(
            id: 1, splitDistanceMeters: 1000,
            cumulativeDistanceMeters: 1000, durationSeconds: 90,
            cumulativeDurationSeconds: 90, avgHeartRate: nil
        )
        XCTAssertEqual(split.formattedDuration(), "1:30")
    }

    // MARK: - CardioSession distance

    func testFormattedDistanceKm() {
        let session = CardioSession(distanceMeters: 5000)
        XCTAssertEqual(session.formattedDistance(useKm: true), "5.00 km")
    }

    func testFormattedDistanceMi() {
        // 5 km ≈ 3.11 mi
        let session = CardioSession(distanceMeters: 5000)
        XCTAssertEqual(session.formattedDistance(useKm: false), "3.11 mi")
    }

    // MARK: - CardioSession pace

    func testAvgPaceForFiveKmInTwentyFiveMinutes() {
        let session = CardioSession(durationSeconds: 25 * 60, distanceMeters: 5000)
        // 25 min / 5 km = 5 min/km = 300 s/km
        XCTAssertEqual(session.avgPaceSecPerKm, 300, accuracy: 0.001)
    }

    func testAvgPaceWithZeroDistance() {
        let session = CardioSession(durationSeconds: 600, distanceMeters: 0)
        XCTAssertEqual(session.avgPaceSecPerKm, 0)
    }

    func testFormattedPaceShowsDashesWhenInvalid() {
        let session = CardioSession(durationSeconds: 0, distanceMeters: 0)
        XCTAssertEqual(session.formattedPace(useKm: true), "--:--")
    }

    func testFormattedPaceWithKmSuffix() {
        let session = CardioSession(durationSeconds: 25 * 60, distanceMeters: 5000)
        let pace = session.formattedPace(useKm: true)
        XCTAssertTrue(pace.contains("5:00"))
        XCTAssertTrue(pace.hasSuffix("/ km"))
    }

    // MARK: - CardioSession duration

    func testFormattedDurationUnderHour() {
        let session = CardioSession(durationSeconds: 1530)   // 25:30
        XCTAssertEqual(session.formattedDuration, "25:30")
    }

    func testFormattedDurationOverHour() {
        let session = CardioSession(durationSeconds: 3725)   // 1:02:05
        XCTAssertEqual(session.formattedDuration, "1:02:05")
    }

    // MARK: - Estimated calories

    func testRunningCaloriesUseRunningMET() {
        let session = CardioSession(
            type: .outdoorRun,
            durationSeconds: 30 * 60,
            distanceMeters: 5000
        )
        // MET 9.8 × 70 kg × 0.5 h = 343 kcal
        XCTAssertEqual(session.estimatedCalories(), 343, accuracy: 1.0)
    }

    func testWalkingHasLowerCalorieEstimate() {
        let walk = CardioSession(type: .outdoorWalk, durationSeconds: 30 * 60)
        let run  = CardioSession(type: .outdoorRun,  durationSeconds: 30 * 60)
        XCTAssertLessThan(walk.estimatedCalories(), run.estimatedCalories())
    }

    func testHeavierUserBurnsMoreCalories() {
        let session = CardioSession(type: .outdoorRun, durationSeconds: 30 * 60)
        let lighter = session.estimatedCalories(bodyWeightKg: 60)
        let heavier = session.estimatedCalories(bodyWeightKg: 90)
        XCTAssertGreaterThan(heavier, lighter)
    }

    // MARK: - start / end accessors (v1.5-review timestamp fix)
    //
    // The legacy `date` field meant different things to different
    // writers — Watch + iPhone recorders stored finish time, Strava
    // import stored start time. New writers populate startDate/endDate
    // explicitly; the `start` / `end` accessors are what every reader
    // (HealthKit save, Strava upload, UI) is supposed to use.

    func testStartFallsBackToDateForLegacyRows() {
        // Legacy session: only `date` populated; startDate/endDate nil.
        // `start` must return `date` so old data still produces a valid
        // HealthKit window via the accessor.
        let legacy = CardioSession(durationSeconds: 1800)
        let stamp = legacy.date
        XCTAssertEqual(legacy.start, stamp,
                       "Legacy rows: .start should equal the stored .date")
    }

    func testEndFallsBackToStartPlusDurationForLegacyRows() {
        // Legacy session: end should be derived from start + duration
        // so HealthKit's beginCollection / endCollection get a sane
        // window even without an explicit endDate on disk.
        let legacy = CardioSession(durationSeconds: 1800)
        let expected = legacy.start.addingTimeInterval(1800)
        XCTAssertEqual(legacy.end.timeIntervalSinceReferenceDate,
                       expected.timeIntervalSinceReferenceDate,
                       accuracy: 0.001)
    }

    func testInitPopulatesBothStartDateAndEndDateExplicitly() {
        // New writers (CardioActiveView, StravaImportService, watch
        // payload persistence) all flow through the standard init.
        // After it runs, both fields must be populated — falling back
        // to the legacy `date` accessor for new sessions would
        // perpetuate the v1.5-review timestamp ambiguity.
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let session = CardioSession(date: start, durationSeconds: 2400)
        XCTAssertEqual(session.startDate, start)
        XCTAssertEqual(session.endDate,
                       start.addingTimeInterval(2400))
        // Legacy `date` field also mirrors start, so any reader that
        // hasn't migrated to `.start` still sees a sensible value.
        XCTAssertEqual(session.date, start)
    }

    func testEndAccessorPrefersExplicitEndDateOverDuration() {
        // Defensive: if a future writer ever sets endDate without
        // exactly matching start + duration (e.g. a session that was
        // paused — durationSeconds is "active time", end is wall-clock),
        // the accessor should trust the explicit field.
        let start = Date(timeIntervalSinceReferenceDate: 700_000_000)
        let session = CardioSession(date: start, durationSeconds: 1800)
        // Override the end to mimic a paused session: 60-min wall-clock
        // window, 30-min active duration.
        session.endDate = start.addingTimeInterval(3600)
        XCTAssertEqual(session.end.timeIntervalSinceReferenceDate,
                       start.addingTimeInterval(3600).timeIntervalSinceReferenceDate,
                       accuracy: 0.001,
                       "Explicit endDate must win over start+duration")
    }
}
