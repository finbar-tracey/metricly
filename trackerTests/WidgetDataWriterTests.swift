import XCTest
@testable import tracker

/// Tests for the merge semantics introduced in 1.5. Before the fix,
/// `WidgetDataWriter.update(...)` overwrote the entire snapshot with whatever
/// values the caller passed (often zeros for fields they didn't know), so
/// finishing a workout would clobber the streak/cardio/weekly counts.
final class WidgetDataWriterTests: XCTestCase {

    private let suiteName = WidgetAppGroup.suiteName

    override func setUp() {
        super.setUp()
        // Clean state so tests don't interfere with each other or the live cache
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: "widgetData")
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: "widgetData")
        super.tearDown()
    }

    private func currentSnapshot() -> WidgetDataWriter.WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: "widgetData") else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetDataWriter.WidgetSnapshot.self, from: data)
    }

    // MARK: - Initial write

    func testFirstUpdateWritesAllProvidedFields() {
        WidgetDataWriter.update(
            streakDays: 5,
            todayWorkoutName: "Push Day",
            weeklyCardioKm: 12.5,
            weeklyGoal: 4,
            workoutsThisWeek: 3
        )
        let snap = currentSnapshot()
        XCTAssertEqual(snap?.streakDays, 5)
        XCTAssertEqual(snap?.todayWorkoutName, "Push Day")
        XCTAssertEqual(snap?.weeklyCardioKm, 12.5)
        XCTAssertEqual(snap?.weeklyGoal, 4)
        XCTAssertEqual(snap?.workoutsThisWeek, 3)
    }

    // MARK: - Merge semantics

    func testPartialUpdatePreservesUnspecifiedFields() {
        // Simulate the full app-launch update
        WidgetDataWriter.update(
            streakDays: 7,
            todayWorkoutName: "Pull Day",
            weeklyCardioKm: 15.0,
            weeklyGoal: 4,
            workoutsThisWeek: 4
        )

        // Now simulate FinishWorkoutSheet — only updates a couple of fields
        WidgetDataWriter.update(todayWorkoutName: "Pull Day (logged)")

        let snap = currentSnapshot()
        XCTAssertEqual(snap?.streakDays, 7, "Streak must survive partial updates")
        XCTAssertEqual(snap?.weeklyCardioKm, 15.0, "Cardio km must survive partial updates")
        XCTAssertEqual(snap?.workoutsThisWeek, 4, "Weekly count must survive partial updates")
        XCTAssertEqual(snap?.todayWorkoutName, "Pull Day (logged)", "Provided field updates")
    }

    func testCardioFinishOnlyUpdatesRunStats() {
        // Initial snapshot
        WidgetDataWriter.update(
            streakDays: 10,
            weeklyCardioKm: 20.0,
            workoutsThisWeek: 5
        )

        // CardioActiveView finishing a session — should ONLY update last run stats
        WidgetDataWriter.update(
            lastRunPace: "5:30 /km",
            lastRunDist: "5.0 km"
        )

        let snap = currentSnapshot()
        XCTAssertEqual(snap?.streakDays, 10)
        XCTAssertEqual(snap?.weeklyCardioKm, 20.0)
        XCTAssertEqual(snap?.workoutsThisWeek, 5)
        XCTAssertEqual(snap?.lastRunPace, "5:30 /km")
        XCTAssertEqual(snap?.lastRunDist, "5.0 km")
    }

    func testExplicitZeroOverwritesField() {
        // The non-nil-means-write rule: passing 0 explicitly is still a write
        WidgetDataWriter.update(streakDays: 5)
        XCTAssertEqual(currentSnapshot()?.streakDays, 5)

        WidgetDataWriter.update(streakDays: 0)
        XCTAssertEqual(currentSnapshot()?.streakDays, 0)
    }

    // MARK: - Default snapshot when nothing exists yet

    func testFirstWriteOnEmptyStoreUsesDefaults() {
        // No prior snapshot exists. Update only one field and check the rest are
        // populated from `WidgetSnapshot()`'s default initializer (all zeros / "").
        WidgetDataWriter.update(streakDays: 3)
        let snap = currentSnapshot()
        XCTAssertEqual(snap?.streakDays, 3)
        XCTAssertEqual(snap?.todayWorkoutName, "")
        XCTAssertEqual(snap?.weeklyCardioKm, 0)
        XCTAssertEqual(snap?.workoutsThisWeek, 0)
    }
}
