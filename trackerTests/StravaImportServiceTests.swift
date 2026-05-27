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
        let activities = [activity(id: 1), activity(id: 2)]

        // First pass: import both.
        let first = StravaImportService.importActivities(activities, existing: [], in: context)
        XCTAssertEqual(first.imported, 2)

        // Build the "existing" list the way the UI would — direct from
        // the just-inserted sessions.
        let now = try context.fetch(FetchDescriptor<CardioSession>())

        // Second pass with the same activities: should skip both.
        let second = StravaImportService.importActivities(activities, existing: now, in: context)
        XCTAssertEqual(second.imported, 0)
        XCTAssertEqual(second.skippedExisting, 2)
    }
}
