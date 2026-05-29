import XCTest
@testable import tracker
import SwiftData

/// Tests for StravaImportService — the network is mocked out by calling
/// `importActivities(_:existing:in:)` directly with hand-rolled
/// SummaryActivity values.
@MainActor
final class StravaImportServiceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: CardioSession.self, configurations: config)
        return ModelContext(container)
    }

    private func activity(
        id: Int = 1,
        name: String = "Test",
        sport: String = "Run",
        startISO: String = "2026-04-15T08:30:00Z",
        elapsed: Double = 1800,
        distance: Double = 5000,
        elev: Double? = 50,
        avgHR: Double? = 150,
        maxHR: Double? = 175,
        calories: Double? = 350,
        trainer: Bool? = nil
    ) -> StravaSummaryActivity {
        StravaSummaryActivity(
            id: id,
            name: name,
            sport_type: sport,
            start_date: startISO,
            elapsed_time: elapsed,
            distance: distance,
            total_elevation_gain: elev,
            average_heartrate: avgHR,
            max_heartrate: maxHR,
            calories: calories,
            trainer: trainer
        )
    }

    // MARK: - sport_type mapping

    func testMapRun() {
        XCTAssertEqual(StravaImportService.mapSportType("Run", trainer: nil), .outdoorRun)
        XCTAssertEqual(StravaImportService.mapSportType("Run", trainer: false), .outdoorRun)
        XCTAssertEqual(StravaImportService.mapSportType("Run", trainer: true), .indoorRun)
    }

    func testMapWalk() {
        XCTAssertEqual(StravaImportService.mapSportType("Walk", trainer: nil), .outdoorWalk)
        XCTAssertEqual(StravaImportService.mapSportType("Walk", trainer: true), .indoorWalk)
    }

    func testMapRideVariants() {
        // All bike-family sport_types collapse to .outdoorCycle today;
        // a future schema bump may split indoor cycle into its own bucket.
        XCTAssertEqual(StravaImportService.mapSportType("Ride", trainer: nil), .outdoorCycle)
        XCTAssertEqual(StravaImportService.mapSportType("MountainBikeRide", trainer: nil), .outdoorCycle)
        XCTAssertEqual(StravaImportService.mapSportType("GravelRide", trainer: nil), .outdoorCycle)
        XCTAssertEqual(StravaImportService.mapSportType("EBikeRide", trainer: nil), .outdoorCycle)
    }

    func testMapTrailAndVirtualRun() {
        XCTAssertEqual(StravaImportService.mapSportType("TrailRun", trainer: nil), .outdoorRun)
        XCTAssertEqual(StravaImportService.mapSportType("VirtualRun", trainer: nil), .outdoorRun)
        // Virtual runs are typically indoor, but Strava lets the user
        // tag them either way — respect the trainer flag.
        XCTAssertEqual(StravaImportService.mapSportType("VirtualRun", trainer: true), .indoorRun)
    }

    func testMapUnsupportedReturnsNil() {
        XCTAssertNil(StravaImportService.mapSportType("Swim", trainer: nil))
        XCTAssertNil(StravaImportService.mapSportType("Hike", trainer: nil))
        XCTAssertNil(StravaImportService.mapSportType("Yoga", trainer: nil))
        XCTAssertNil(StravaImportService.mapSportType("Unknown", trainer: nil))
    }

    // MARK: - makeSession field mapping

    func testMakeSessionPopulatesEveryField() {
        let a = activity(id: 42, name: "Easy 5k", sport: "Run", elapsed: 1500, distance: 5200, elev: 80, avgHR: 148, maxHR: 165, calories: 320)
        let session = StravaImportService.makeSession(from: a, type: .outdoorRun)

        XCTAssertEqual(session.title, "Easy 5k")
        XCTAssertEqual(session.type, .outdoorRun)
        XCTAssertEqual(session.durationSeconds, 1500)
        XCTAssertEqual(session.distanceMeters, 5200)
        XCTAssertEqual(session.elevationGainMeters, 80)
        XCTAssertEqual(session.avgHeartRate, 148)
        XCTAssertEqual(session.maxHeartRate, 165)
        XCTAssertEqual(session.caloriesBurned, 320)
        XCTAssertEqual(session.stravaActivityID, 42)
    }

    func testMakeSessionHandlesMissingOptionals() {
        // Strava sometimes omits HR / calories for activities recorded
        // without a sensor. The mapping should leave those as nil
        // (not zero — distinguishing absence from "0 calories" matters).
        let a = activity(id: 99, sport: "Walk", elev: nil, avgHR: nil, maxHR: nil, calories: nil)
        let session = StravaImportService.makeSession(from: a, type: .outdoorWalk)

        XCTAssertEqual(session.elevationGainMeters, 0)   // we default to 0
        XCTAssertNil(session.avgHeartRate)
        XCTAssertNil(session.maxHeartRate)
        XCTAssertNil(session.caloriesBurned)
    }

    func testMakeSessionParsesISO8601() {
        let a = activity(startISO: "2026-04-15T08:30:00Z")
        let session = StravaImportService.makeSession(from: a, type: .outdoorRun)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        XCTAssertEqual(session.date, formatter.date(from: "2026-04-15T08:30:00Z"))
    }

    // MARK: - Dedup

    func testDedupSkipsAlreadyImportedActivities() throws {
        let context = try makeContext()

        // Pre-existing session that was already imported.
        let prior = CardioSession(date: .now, title: "Already there", type: .outdoorRun)
        prior.stravaActivityID = 100
        context.insert(prior)

        let activities = [
            activity(id: 100, name: "Same activity"),
            activity(id: 101, name: "New activity"),
        ]
        let result = StravaImportService.importActivities(
            activities,
            existing: [prior],
            in: context
        )

        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skippedExisting, 1)
        XCTAssertEqual(result.unsupportedType, 0)
    }

    func testUnsupportedTypeIsCountedSeparately() throws {
        let context = try makeContext()

        let activities = [
            activity(id: 1, sport: "Run"),
            activity(id: 2, sport: "Swim"),       // unsupported
            activity(id: 3, sport: "Hike"),       // unsupported
            activity(id: 4, sport: "Ride"),
        ]
        let result = StravaImportService.importActivities(activities, existing: [], in: context)

        XCTAssertEqual(result.imported, 2)
        XCTAssertEqual(result.skippedExisting, 0)
        XCTAssertEqual(result.unsupportedType, 2)
    }

    func testEmptyImportReturnsEmptyResult() throws {
        let context = try makeContext()
        let result = StravaImportService.importActivities([], existing: [], in: context)
        XCTAssertEqual(result, StravaImportService.Result())
    }

    func testRerunningSyncDoesNotDuplicate() throws {
        let context = try makeContext()
        // Two genuinely different activities — distinct start times
        // and distances so the fuzzy-dedup layer doesn't collapse them
        // into one. This test specifically exercises the ID-based
        // dedup layer on the rerun.
        let activities = [
            activity(id: 1, startISO: "2026-04-15T08:30:00Z",
                     elapsed: 1800, distance: 5000),
            activity(id: 2, startISO: "2026-04-16T18:00:00Z",
                     elapsed: 2400, distance: 7500),
        ]

        // First pass: import both.
        let first = StravaImportService.importActivities(activities, existing: [], in: context)
        XCTAssertEqual(first.imported, 2)

        // Build the "existing" list the way the UI would — direct from
        // the just-inserted sessions.
        let now = try context.fetch(FetchDescriptor<CardioSession>())

        // Second pass with the same activities: should skip both via
        // the ID layer (stravaActivityID is set on each).
        let second = StravaImportService.importActivities(activities, existing: now, in: context)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.skippedExisting, 2)
    }

    // MARK: - Fuzzy dedup against HealthKit-imported / app-recorded sessions
    //
    // The common real-world path: user records a run on Apple Watch.
    // The run lands in Apple Health (becomes a HealthKit Workout) and
    // also auto-shares to Strava. Metricly imports Strava — without
    // fuzzy dedup, the user gets a duplicate cardio row for the same
    // physical event. These tests pin the tolerance windows and the
    // behaviour around the boundary so a future retune is intentional.

    /// Build a non-Strava CardioSession (no stravaActivityID) so the
    /// ID-based dedup layer doesn't catch it. This is what an
    /// HKWorkout-imported or app-recorded session looks like to the
    /// fuzzy matcher.
    private func nonStravaSession(
        date: Date,
        type: CardioType = .outdoorRun,
        duration: Double = 1800,
        distance: Double = 5000
    ) -> CardioSession {
        CardioSession(
            date: date,
            title: "From Apple Health",
            type: type,
            durationSeconds: duration,
            distanceMeters: distance
        )
    }

    func testFuzzyDedupSkipsHealthKitOriginRunWithinTolerance() throws {
        // The canonical case. A run already exists from Apple Health
        // (no stravaActivityID). The user imports Strava and the same
        // run comes through. Fuzzy match must catch it.
        let context = try makeContext()
        let startISO = "2026-04-15T08:30:00Z"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.date(from: startISO) ?? .now

        let existing = nonStravaSession(date: start)
        context.insert(existing)

        // Strava version: identical timing, off by 2 seconds on start
        // and 5m on distance — all comfortably inside the windows.
        let stravaSide = activity(id: 999, startISO: startISO,
                                  elapsed: 1800, distance: 5005)
        let result = StravaImportService.importActivities(
            [stravaSide], existing: [existing], in: context
        )
        XCTAssertEqual(result.imported, 0)
        XCTAssertEqual(result.skippedExisting, 1)
    }

    func testFuzzyDedupDoesNotMergeDifferentTypes() throws {
        // Same time, same distance, different activity types. Should
        // never merge — a run and a walk at 8 AM are two real events.
        let context = try makeContext()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.date(from: "2026-04-15T08:30:00Z") ?? .now

        let run = nonStravaSession(date: start, type: .outdoorRun)
        let walkStrava = activity(id: 1, sport: "Walk",
                                  startISO: "2026-04-15T08:30:00Z",
                                  elapsed: 1800, distance: 5000)
        let result = StravaImportService.importActivities(
            [walkStrava], existing: [run], in: context
        )
        XCTAssertEqual(result.imported, 1,
                       "Type mismatch should not be fuzzy-deduped")
    }

    func testFuzzyDedupRespectsStartTimeWindow() throws {
        // Boundary: a Strava activity ~6 min later than an existing
        // session should NOT merge (window is 5 min). Catches drift in
        // either direction of the constant.
        let context = try makeContext()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let baseStart = formatter.date(from: "2026-04-15T08:30:00Z") ?? .now
        let sixMinLater = baseStart.addingTimeInterval(6 * 60)
        let sixMinISO = formatter.string(from: sixMinLater)

        let existing = nonStravaSession(date: baseStart)
        let stravaSide = activity(id: 1, startISO: sixMinISO)
        let result = StravaImportService.importActivities(
            [stravaSide], existing: [existing], in: context
        )
        XCTAssertEqual(result.imported, 1,
                       "Outside startWindow should not merge")
    }

    func testFuzzyDedupRespectsDistanceWindow() throws {
        // Boundary: 200m difference exceeds the 100m window.
        let context = try makeContext()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.date(from: "2026-04-15T08:30:00Z") ?? .now

        let existing = nonStravaSession(date: start, distance: 5000)
        let stravaSide = activity(id: 1, startISO: "2026-04-15T08:30:00Z",
                                  elapsed: 1800, distance: 5200)
        let result = StravaImportService.importActivities(
            [stravaSide], existing: [existing], in: context
        )
        XCTAssertEqual(result.imported, 1,
                       "Outside distanceWindow should not merge")
    }

    func testFuzzyDedupRespectsDurationWindow() throws {
        // 120s duration difference exceeds the 60s window.
        let context = try makeContext()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.date(from: "2026-04-15T08:30:00Z") ?? .now

        let existing = nonStravaSession(date: start, duration: 1800)
        let stravaSide = activity(id: 1, startISO: "2026-04-15T08:30:00Z",
                                  elapsed: 1920, distance: 5000)
        let result = StravaImportService.importActivities(
            [stravaSide], existing: [existing], in: context
        )
        XCTAssertEqual(result.imported, 1,
                       "Outside durationWindow should not merge")
    }

    func testIsFuzzyDuplicatePredicateIsSymmetric() throws {
        // Pure predicate: same arguments swapped should produce the
        // same result. Catches future implementations that
        // accidentally lean on one side's data (e.g. picking
        // existing.distance as the baseline).
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let start = formatter.date(from: "2026-04-15T08:30:00Z") ?? .now

        let a = nonStravaSession(date: start)
        let b = nonStravaSession(date: start.addingTimeInterval(60))

        XCTAssertEqual(
            StravaImportService.isFuzzyDuplicate(a, of: b),
            StravaImportService.isFuzzyDuplicate(b, of: a)
        )
    }

    func testDedupCatchesDuplicateIDsInsideSingleResponse() throws {
        // Strava's `/activities` endpoint pages with cursor-based
        // pagination; under heavy load, the same activity can appear
        // on two adjacent pages. The fix is the mutable `seenIDs` set
        // inside the loop — first hit imports, second hit skips.
        let context = try makeContext()
        let dup = activity(id: 42)
        let result = StravaImportService.importActivities(
            [dup, dup], existing: [], in: context
        )
        XCTAssertEqual(result.imported, 1)
        XCTAssertEqual(result.skippedExisting, 1)
    }
}
