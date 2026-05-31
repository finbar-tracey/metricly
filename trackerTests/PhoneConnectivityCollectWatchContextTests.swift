import XCTest
import SwiftData
@testable import tracker

@MainActor
final class PhoneConnectivityCollectWatchContextTests: XCTestCase {

    override func setUp() {
        super.setUp()
        TodayPlanStore.resetForTests()
        PhoneConnectivityManager.shared.modelContext = nil
    }

    override func tearDown() {
        TodayPlanStore.resetForTests()
        PhoneConnectivityManager.shared.modelContext = nil
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

    func testCollectWatchContextIncludesPlanStreakAndSettings() throws {
        let container = try makeContainer()
        let ctx = container.mainContext

        let settings = UserSettings()
        settings.useKilograms = false
        settings.defaultRestDuration = 120
        let weekday = Calendar.current.component(.weekday, from: .now)
        settings.weeklyPlan = [weekday: "Push Day"]
        ctx.insert(settings)

        let finished = Workout(name: "Push Day", date: .now)
        finished.endTime = .now
        ctx.insert(finished)

        let exercise = Exercise(name: "Bench Press", workout: finished, category: .chest)
        ctx.insert(exercise)

        let plan = TodayPlan(
            scheduledName: "Push Day",
            recommendedName: "Moderate upper",
            intensity: .moderate,
            reasons: ["Sleep OK"],
            adjustments: [],
            confidence: .medium,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: [],
            generatedAt: .now
        )
        TodayPlanStore.save(plan)

        let context = WatchContextBuilder.build(from: ctx)

        XCTAssertEqual(context[WatchMessageKey.useKilograms] as? Bool, false)
        XCTAssertEqual(context[WatchMessageKey.restDuration] as? Int, 120)
        XCTAssertEqual(context[WatchMessageKey.todayPlan] as? String, "Push Day")
        XCTAssertEqual(context[WatchMessageKey.adaptivePlanName] as? String, "Moderate upper")
        XCTAssertEqual(context[WatchMessageKey.adaptiveIntensity] as? String, TodayPlan.Intensity.moderate.rawValue)
        XCTAssertEqual(context[WatchMessageKey.adaptiveTopReason] as? String, "Sleep OK")
        XCTAssertEqual(context[WatchMessageKey.currentStreak] as? Int, 1)
        XCTAssertEqual(context[WatchMessageKey.exerciseList] as? [String], ["Bench Press"])
    }

    func testManagerCollectDelegatesToBuilder() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(UserSettings())
        let built = WatchContextBuilder.build(from: ctx)
        PhoneConnectivityManager.shared.modelContext = ctx
        let collected = PhoneConnectivityManager.shared.collectWatchContext()
        XCTAssertEqual(collected[WatchMessageKey.restDuration] as? Int, built[WatchMessageKey.restDuration] as? Int)
    }

    func testCollectWatchContextEmptyWithoutModelContext() {
        PhoneConnectivityManager.shared.modelContext = nil
        XCTAssertTrue(PhoneConnectivityManager.shared.collectWatchContext().isEmpty)
    }

    func testWatchContextBuilderDirectlyMatchesManager() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        ctx.insert(UserSettings())
        try ctx.save()

        let built = WatchContextBuilder.build(from: ctx)
        PhoneConnectivityManager.shared.modelContext = ctx
        let collected = PhoneConnectivityManager.shared.collectWatchContext()

        XCTAssertEqual(built[WatchMessageKey.restDuration] as? Int, collected[WatchMessageKey.restDuration] as? Int)
        XCTAssertEqual(built[WatchMessageKey.useKilograms] as? Bool, collected[WatchMessageKey.useKilograms] as? Bool)
    }

    func testWatchPayloadPersistenceRoundTrip() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let settings = UserSettings()
        settings.defaultRestDuration = 90
        ctx.insert(settings)

        let workoutPayload = WatchWorkoutPayload(
            id: UUID(),
            name: "Watch Bench",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            totalCalories: 120,
            avgHeartRate: 110,
            maxHeartRate: 140,
            exercises: [
                WatchExercisePayload(
                    name: "Bench Press",
                    sets: [WatchSetPayload(reps: 5, weightKg: 80, isWarmUp: false)]
                ),
            ]
        )
        WatchPayloadPersistence.persistWorkout(workoutPayload, in: ctx)
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].name, "Watch Bench")

        let cardioPayload = WatchCardioPayload(
            id: UUID(),
            date: Date(timeIntervalSince1970: 3_000),
            activityTypeRaw: CardioType.outdoorRun.rawValue,
            durationSeconds: 1200,
            distanceMeters: 4000,
            avgHeartRate: 155,
            maxHeartRate: 175,
            calories: 300,
            elevationGain: 25
        )
        WatchPayloadPersistence.persistCardio(cardioPayload, in: ctx)
        let sessions = try ctx.fetch(FetchDescriptor<CardioSession>())
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions[0].distanceMeters, 4000, accuracy: 0.01)

        PhoneConnectivityManager.shared.modelContext = ctx
        let context = PhoneConnectivityManager.shared.collectWatchContext()
        XCTAssertFalse(context.isEmpty)
        XCTAssertEqual(context[WatchMessageKey.restDuration] as? Int, 90)
    }
}
