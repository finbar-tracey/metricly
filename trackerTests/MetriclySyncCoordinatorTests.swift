import XCTest
@testable import tracker

/// Verifies coordinator publish methods delegate to WidgetDataWriter merge semantics.
final class MetriclySyncCoordinatorTests: XCTestCase {

    private let suiteName = WidgetAppGroup.suiteName

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: "widgetData")
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removeObject(forKey: "widgetData")
        super.tearDown()
    }

    private func snapshot() -> WidgetDataWriter.WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: "widgetData") else { return nil }
        return try? JSONDecoder().decode(WidgetDataWriter.WidgetSnapshot.self, from: data)
    }

    func testPublishAfterWorkoutFinishPreservesOtherFields() {
        WidgetDataWriter.update(streakDays: 4, weeklyGoal: 5, workoutsThisWeek: 2)
        let workout = Workout(name: "Leg Day", date: .now)
        let settings = UserSettings()
        settings.weeklyGoal = 6

        MetriclySyncCoordinator.publishAfterWorkoutFinish(workout: workout, settings: settings)

        let snap = snapshot()
        XCTAssertEqual(snap?.streakDays, 4)
        XCTAssertEqual(snap?.workoutsThisWeek, 2)
        XCTAssertEqual(snap?.todayWorkoutName, "Leg Day")
        XCTAssertEqual(snap?.weeklyGoal, 6)
    }

    func testPublishAfterCardioFinishPreservesStreak() {
        WidgetDataWriter.update(streakDays: 9, weeklyCardioKm: 18.0)
        let session = CardioSession(
            date: .now,
            type: .outdoorRun,
            durationSeconds: 1800,
            distanceMeters: 5000
        )

        MetriclySyncCoordinator.publishAfterCardioFinish(session: session, useKm: true)

        let snap = snapshot()
        XCTAssertEqual(snap?.streakDays, 9)
        XCTAssertEqual(snap?.weeklyCardioKm, 18.0)
        XCTAssertFalse(snap?.lastRunDist.isEmpty ?? true)
    }

    func testPublishWaterWritesWaterPayload() {
        MetriclySyncCoordinator.publishWater(todayMl: 1200, goalMl: 2500)
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: "waterWidgetData") else {
            XCTFail("Expected water widget payload")
            return
        }
        let decoded = try? JSONDecoder().decode(WidgetDataWriter.WaterWidgetData.self, from: data)
        XCTAssertEqual(decoded?.todayMl, 1200)
        XCTAssertEqual(decoded?.goalMl, 2500)
    }

    func testPublishCaffeineWritesCaffeinePayload() {
        let entries = [(date: Date(), milligrams: 95.0)]
        MetriclySyncCoordinator.publishCaffeine(
            entries: entries,
            halfLifeHours: 5.0,
            dailyLimitMg: 400
        )
        guard let data = UserDefaults(suiteName: suiteName)?.data(forKey: "caffeineWidgetData") else {
            XCTFail("Expected caffeine widget payload")
            return
        }
        let decoded = try? JSONDecoder().decode(WidgetDataWriter.CaffeineWidgetData.self, from: data)
        XCTAssertEqual(decoded?.entries.count, 1)
        XCTAssertEqual(decoded?.halfLifeHours, 5.0)
        XCTAssertEqual(decoded?.dailyLimitMg, 400)
    }
}
