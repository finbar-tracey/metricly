import XCTest
import SwiftData
@testable import tracker

@MainActor
final class WatchContextBuilderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TodayPlanStore.resetForTests()
    }

    override func tearDown() {
        TodayPlanStore.resetForTests()
        super.tearDown()
    }

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: UserSettings.self,
            Workout.self,
            Exercise.self,
            CardioSession.self,
            TrainingBlock.self,
            configurations: config
        )
    }

    func testBuildIncludesCoreKeysAndTypes() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let settings = UserSettings()
        settings.defaultRestDuration = 90
        settings.useKilograms = true
        ctx.insert(settings)

        let plan = TodayPlan(
            scheduledName: "Leg Day",
            recommendedName: "Heavy lower",
            intensity: .hard,
            reasons: ["Well rested"],
            adjustments: [],
            confidence: .high,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: [],
            generatedAt: .now
        )
        TodayPlanStore.save(plan)

        let built = WatchContextBuilder.build(from: ctx)
        let keys = Set(built.keys)

        XCTAssertTrue(keys.contains(WatchMessageKey.restDuration))
        XCTAssertTrue(keys.contains(WatchMessageKey.useKilograms))
        XCTAssertTrue(keys.contains(WatchMessageKey.adaptivePlanName))
        XCTAssertEqual(built[WatchMessageKey.restDuration] as? Int, 90)
        XCTAssertEqual(built[WatchMessageKey.useKilograms] as? Bool, true)
        XCTAssertEqual(built[WatchMessageKey.adaptivePlanName] as? String, "Heavy lower")
        XCTAssertEqual(built[WatchMessageKey.adaptiveIntensity] as? String, TodayPlan.Intensity.hard.rawValue)
    }

    func testBuildEmptyExerciseListWithoutData() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(UserSettings())
        let built = WatchContextBuilder.build(from: ctx)
        XCTAssertEqual(built[WatchMessageKey.currentStreak] as? Int, 0)
        XCTAssertTrue((built[WatchMessageKey.exerciseList] as? [String])?.isEmpty ?? true)
    }
}
