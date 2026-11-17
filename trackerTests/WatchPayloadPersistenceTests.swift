import XCTest
import SwiftData
@testable import tracker

@MainActor
final class WatchPayloadPersistenceTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: MetriclySchema.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return container.mainContext
    }

    private func workoutPayload(id: UUID = UUID()) -> WatchWorkoutPayload {
        WatchWorkoutPayload(
            id: id, name: "Push", startDate: .now.addingTimeInterval(-3600), endDate: .now,
            totalCalories: nil, avgHeartRate: nil, maxHeartRate: nil,
            exercises: [WatchExercisePayload(name: "Bench", sets: [
                WatchSetPayload(reps: 5, weightKg: 100, isWarmUp: false)
            ])]
        )
    }

    func testDuplicateWorkoutPayloadIsSkipped() throws {
        let ctx = try makeContext()
        let p = workoutPayload()
        XCTAssertTrue(WatchPayloadPersistence.persistWorkout(p, in: ctx))
        XCTAssertTrue(WatchPayloadPersistence.persistWorkout(p, in: ctx))
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Workout>()), 1)
    }

    func testDuplicateCardioPayloadIsSkipped() throws {
        let ctx = try makeContext()
        let p = WatchCardioPayload(id: UUID(), date: .now, activityTypeRaw: CardioType.outdoorRun.rawValue,
                                   durationSeconds: 600, distanceMeters: 1000, avgHeartRate: nil,
                                   maxHeartRate: nil, calories: nil, elevationGain: 0)
        WatchPayloadPersistence.persistCardio(p, in: ctx)
        WatchPayloadPersistence.persistCardio(p, in: ctx)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<CardioSession>()), 1)
    }

    func testPayloadsQueuedUntilContextSet() throws {
        let manager = PhoneConnectivityManager.shared
        manager.modelContext = nil
        manager.pendingWorkoutPayloads = []
        let p = workoutPayload()
        manager.persistWorkout(p)
        XCTAssertEqual(manager.pendingWorkoutPayloads.count, 1)

        let ctx = try makeContext()
        manager.modelContext = ctx
        XCTAssertTrue(manager.pendingWorkoutPayloads.isEmpty)
        XCTAssertEqual(try ctx.fetchCount(FetchDescriptor<Workout>()), 1)
        manager.modelContext = nil
    }

    func testStoreFailureClassifier() {
        let corrupt = NSError(domain: NSCocoaErrorDomain, code: 134110)
        let wrapped = NSError(domain: "SwiftData", code: 1, userInfo: [NSUnderlyingErrorKey: corrupt])
        XCTAssertTrue(StoreFailureClassifier.isLikelyCorruption(wrapped))
        XCTAssertFalse(StoreFailureClassifier.isLikelyCorruption(NSError(domain: NSCocoaErrorDomain, code: 640)))
    }

    /// Documents the limitation described in MetriclySchema: every
    /// versioned schema aliases the live classes, so stages are not backed
    /// by frozen snapshots.
    func testMigrationPlanAliasesLiveClasses() {
        XCTAssertTrue(MetriclySchemaV1.models.contains { $0 == Workout.self })
        XCTAssertTrue(MetriclySchemaV5.models.contains { $0 == Workout.self })
        XCTAssertEqual(MetriclyMigrationPlan.stages.count, MetriclyMigrationPlan.schemas.count - 1)
    }
}
