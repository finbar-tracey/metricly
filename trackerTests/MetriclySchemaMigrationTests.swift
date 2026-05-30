import XCTest
import SwiftData
@testable import tracker

/// Round-trip tests for `MetriclyMigrationPlan`.
///
/// Both shipped stages (V1→V2 adds SorenessEntry, V2→V3 adds
/// PlanComplianceEvent) are `.lightweight`. Lightweight means "SwiftData
/// will infer the migration from the diff", which is the cheapest path
/// but also the one where a subtle non-additive change (renaming a
/// field, narrowing an optional, changing a relationship's cascade) can
/// silently flip into a destructive migration — and the failure mode is
/// data loss on the user's first launch after upgrading.
///
/// These tests stand up a V1-shape container on a file URL, write
/// representative data, tear down, then re-open with the full versioned
/// schema + migration plan and assert the original data is still there
/// and the new tables are queryable.
@MainActor
final class MetriclySchemaMigrationTests: XCTestCase {

    /// Temp file URL, unique per test so parallel runs don't collide.
    private var storeURL: URL!

    override func setUp() {
        super.setUp()
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("MetriclyMigrationTests-\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir,
                                                 withIntermediateDirectories: true)
        storeURL = tmpDir.appendingPathComponent("store.sqlite")
    }

    override func tearDown() {
        super.tearDown()
        if let url = storeURL?.deletingLastPathComponent() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Helpers

    /// Write some V1-shape data to a fresh container at `storeURL` and
    /// let the container deallocate (closing the underlying SQLite file)
    /// before this function returns. Critical for the next `open()` to
    /// pick up the persisted state via the migration plan.
    private func seedV1Store() throws {
        try autoreleasepool {
            let config = ModelConfiguration(url: storeURL)
            let v1 = try ModelContainer(for: Schema(versionedSchema: MetriclySchemaV1.self),
                                        configurations: config)
            let ctx = v1.mainContext

            // A finished workout with one exercise + working set.
            let w = Workout(name: "V1 Push", date: .now)
            w.endTime = .now.addingTimeInterval(45 * 60)
            let ex = Exercise(name: "Bench", workout: w, category: .chest)
            ex.sets.append(ExerciseSet(reps: 8, weight: 60, isWarmUp: false, exercise: ex))
            w.exercises.append(ex)
            ctx.insert(w)

            // A cardio session — exercises the other end of the model graph.
            let c = CardioSession(
                date: .now,
                title: "V1 Morning Run",
                type: .outdoorRun,
                durationSeconds: 30 * 60,
                distanceMeters: 5_000
            )
            ctx.insert(c)

            try ctx.save()
        }
    }

    /// Open the same URL through the full migration plan and return the
    /// container. SwiftData walks V1→V2→V3 on first open.
    private func openMigrated() throws -> ModelContainer {
        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: MetriclySchema.schema,
            migrationPlan: MetriclyMigrationPlan.self,
            configurations: config
        )
    }

    // MARK: - Tests

    func testV1DataSurvivesMigrationToV3() throws {
        try seedV1Store()
        let migrated = try openMigrated()
        let ctx = migrated.mainContext

        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1, "Workout written under V1 must survive migration")
        let w = try XCTUnwrap(workouts.first)
        XCTAssertEqual(w.name, "V1 Push")
        XCTAssertNotNil(w.endTime, "endTime must round-trip")
        XCTAssertEqual(w.exercises.count, 1)
        XCTAssertEqual(w.exercises.first?.sets.count, 1)
        XCTAssertEqual(w.exercises.first?.sets.first?.reps, 8)

        let cardios = try ctx.fetch(FetchDescriptor<CardioSession>())
        XCTAssertEqual(cardios.count, 1, "CardioSession written under V1 must survive migration")
        let c = try XCTUnwrap(cardios.first)
        XCTAssertEqual(c.title, "V1 Morning Run")
        XCTAssertEqual(c.durationSeconds, 30 * 60, accuracy: 0.001)
        XCTAssertEqual(c.distanceMeters, 5_000, accuracy: 0.001)
    }

    func testNewV2AndV3TablesAreQueryablePostMigration() throws {
        try seedV1Store()
        let migrated = try openMigrated()
        let ctx = migrated.mainContext

        // The new tables should exist as empty result sets — not crash,
        // not throw. If a lightweight stage was misconfigured these would
        // fail at fetch time with "no such table".
        let soreness = try ctx.fetch(FetchDescriptor<SorenessEntry>())
        XCTAssertTrue(soreness.isEmpty,
                      "SorenessEntry table should exist and be empty after migration from V1")

        let compliance = try ctx.fetch(FetchDescriptor<PlanComplianceEvent>())
        XCTAssertTrue(compliance.isEmpty,
                      "PlanComplianceEvent table should exist and be empty after migration from V1")
    }

    func testNewModelTypesAreWritableAfterMigration() throws {
        try seedV1Store()
        let migrated = try openMigrated()
        let ctx = migrated.mainContext

        // Insert one of each new-in-V2 and new-in-V3 model. If the
        // migration didn't actually upgrade the store version, these
        // inserts would fail to persist because the table doesn't exist
        // in the SQLite schema.
        let soreness = SorenessEntry(date: .now, group: .legs, level: 2)
        ctx.insert(soreness)

        let compliance = PlanComplianceEvent(
            day: .now,
            suggested: .moderate,
            actual: .moderate,
            complied: true
        )
        ctx.insert(compliance)

        try ctx.save()

        XCTAssertEqual(try ctx.fetch(FetchDescriptor<SorenessEntry>()).count, 1)
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<PlanComplianceEvent>()).count, 1)
    }

    func testMigrationPlanContainsExpectedStages() {
        // Locks in the chain so future schema bumps require an explicit
        // edit. Catches the case where someone adds V5 to the schema set
        // but forgets the corresponding stage in the plan.
        XCTAssertEqual(MetriclyMigrationPlan.stages.count, 4,
                       "V1→V2, V2→V3, V3→V4, V4→V5 — bumping this requires a thoughtful migration plan update")
        XCTAssertEqual(MetriclyMigrationPlan.schemas.count, 5,
                       "V1, V2, V3, V4, V5 — same warning applies")
    }

    func testV4FeedbackEventTableIsQueryablePostMigration() throws {
        // V4 added WorkoutFeedbackEvent. After full V1→V4 migration on
        // a populated store, the new table must exist (queryable +
        // writable), and V1 data must still survive — both checks
        // wrapped here so the existing tests' wider span isn't
        // duplicated.
        try seedV1Store()
        let migrated = try openMigrated()
        let ctx = migrated.mainContext

        let events = try ctx.fetch(FetchDescriptor<WorkoutFeedbackEvent>())
        XCTAssertTrue(events.isEmpty,
                      "Feedback table should exist and be empty post-migration from V1")

        // Write one — proves the table is fully realised, not just
        // queryable.
        let event = WorkoutFeedbackEvent(
            day: .now,
            feel: .aboutRight,
            suggested: .moderate
        )
        ctx.insert(event)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<WorkoutFeedbackEvent>()).count, 1)

        // The V1 workout we seeded is still there.
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
    }

    func testV5TrainingBlockTableIsQueryablePostMigration() throws {
        // V5 added TrainingBlock — the periodisation primitive for
        // Sprint 30's adaptive training blocks. After full V1→V5
        // migration on a populated store, the new table must exist
        // (queryable + writable), and V1 data must still survive.
        try seedV1Store()
        let migrated = try openMigrated()
        let ctx = migrated.mainContext

        let blocks = try ctx.fetch(FetchDescriptor<TrainingBlock>())
        XCTAssertTrue(blocks.isEmpty,
                      "Block table should exist and be empty post-migration from V1")

        // Write one — proves the table is fully realised, not just
        // queryable.
        let block = TrainingBlock(
            startDate: .now,
            weekCount: 4,
            phase: .accumulate
        )
        ctx.insert(block)
        try ctx.save()
        XCTAssertEqual(try ctx.fetch(FetchDescriptor<TrainingBlock>()).count, 1)

        // V1 workouts survive untouched.
        let workouts = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(workouts.count, 1)
    }
}
