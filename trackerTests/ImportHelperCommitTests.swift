import XCTest
import SwiftData
@testable import tracker

@MainActor
final class ImportHelperCommitTests: XCTestCase {

    private let strongHeader = "Date,Workout Name,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,Workout Duration"
    private let hevyHeader = "title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe"

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(for: Workout.self, Exercise.self, configurations: config)
    }

    private func strongCSV() -> String {
        """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        2024-01-15 06:30:00,Push,Bench Press,2,80,8,,,,,3600
        """
    }

    func testCommitPreviewInsertsWorkouts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let rows = ImportHelper.parseCSVRows(strongCSV())
        let parsed = StrongParser.parseRows(Array(rows.dropFirst()))
        let preview = ImportHelper.ImportPreview(format: .strong, workouts: parsed)

        let count = ImportHelper.commitPreview(preview, into: ctx)
        XCTAssertEqual(count, 1)

        let stored = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.name, "Push")
        XCTAssertEqual(stored.first?.exercises.count, 1)
        XCTAssertEqual(stored.first?.exercises.first?.sets.count, 2)
    }

    private func hevyCSV() -> String {
        // Real Hevy export shape: 14 columns incl. set_index, and quoted
        // "d MMM yyyy, HH:mm" timestamps (the format HevyParser accepts).
        """
        \(hevyHeader)
        Push Day,"15 Jan 2024, 06:30","15 Jan 2024, 07:30",,Bench Press,,,1,normal,80,8,,,8
        Push Day,"15 Jan 2024, 06:30","15 Jan 2024, 07:30",,Bench Press,,,2,normal,80,8,,,8
        """
    }

    func testCommitHevyPreviewInsertsWorkouts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let rows = ImportHelper.parseCSVRows(hevyCSV())
        let header = rows.first ?? []
        let parsed = HevyParser.parseRows(header: header, rows: Array(rows.dropFirst()))
        let preview = ImportHelper.ImportPreview(format: .hevy, workouts: parsed)

        let count = ImportHelper.commitPreview(preview, into: ctx)
        XCTAssertEqual(count, 1)

        let stored = try ctx.fetch(FetchDescriptor<Workout>())
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.name, "Push Day")
        XCTAssertEqual(stored.first?.exercises.first?.sets.count, 2)
    }

    func testPlanAndCommitPreviewMatchRowCounts() throws {
        let container = try makeContainer()
        let ctx = container.mainContext
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("metricly-strong-\(UUID().uuidString).csv")
        try strongCSV().write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let plan = try ImportHelper.plan(from: tempURL)
        guard case .preview(let preview) = plan else {
            return XCTFail("Expected Strong preview plan")
        }
        let committed = ImportHelper.commitPreview(preview, into: ctx)
        XCTAssertEqual(committed, preview.workoutCount)
    }
}
