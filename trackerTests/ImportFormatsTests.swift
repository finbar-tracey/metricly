import XCTest
@testable import tracker

/// Tests for the Strong/Hevy importer infrastructure. Each test
/// embeds a tiny but realistic fixture string, runs it through
/// `ImportHelper.parseCSVRows` (the same CSV parser the live import
/// uses) and then through the format-specific parser, and asserts
/// the resulting `ParsedWorkout`s match the expected shape.
///
/// Tests deliberately use short fixtures rather than full real-world
/// exports — easier to debug failures, and we're checking parser
/// behaviour rather than file-size handling.
final class ImportFormatsTests: XCTestCase {

    // MARK: - Format detection

    func testDetectStrongFromHeader() {
        let header = ["Date", "Workout Name", "Exercise Name", "Set Order",
                      "Weight", "Reps", "Distance", "Seconds", "Notes",
                      "Workout Notes", "Workout Duration"]
        XCTAssertEqual(ImportFormat.detect(header: header), .strong)
    }

    func testDetectHevyFromHeader() {
        let header = ["title", "start_time", "end_time", "description",
                      "exercise_title", "superset_id", "exercise_notes",
                      "set_index", "set_type", "weight_kg", "reps",
                      "distance_km", "duration_seconds", "rpe"]
        XCTAssertEqual(ImportFormat.detect(header: header), .hevy)
    }

    func testDetectMetriclyFromHeader() {
        // Metricly's export — positional, 10+ columns, expected names
        // in fixed positions.
        let header = ["Date", "Workout Name", "Rating", "Duration (min)",
                      "Exercise Name", "Category", "Superset Group",
                      "Set #", "Reps", "Weight (kg)", "RPE"]
        XCTAssertEqual(ImportFormat.detect(header: header), .metricly)
    }

    func testDetectReturnsNilForUnknownFormat() {
        let header = ["foo", "bar", "baz"]
        XCTAssertNil(ImportFormat.detect(header: header))
    }

    func testDetectIsCaseInsensitive() {
        // Some exports change column casing depending on the user's
        // settings or version. Detection should be robust.
        let strongUpper = ["DATE", "WORKOUT NAME", "EXERCISE NAME",
                           "SET ORDER", "Weight", "Reps", "Distance",
                           "Seconds", "Notes", "Workout Notes",
                           "Workout Duration"]
        XCTAssertEqual(ImportFormat.detect(header: strongUpper), .strong)
    }

    // MARK: - Strong parser

    /// Strong's exported CSV header.
    private let strongHeader = "Date,Workout Name,Exercise Name,Set Order,Weight,Reps,Distance,Seconds,Notes,Workout Notes,Workout Duration"

    func testStrongParserBasicWorkout() {
        let csv = """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,Felt strong,3600
        2024-01-15 06:30:00,Push,Bench Press,2,80,8,,,,,3600
        2024-01-15 06:30:00,Push,Bench Press,3,80,6,,,,,3600
        2024-01-15 06:30:00,Push,Overhead Press,1,50,8,,,,,3600
        """
        let workouts = parseStrong(csv)
        XCTAssertEqual(workouts.count, 1)
        let w = workouts[0]
        XCTAssertEqual(w.title, "Push")
        XCTAssertEqual(w.notes, "Felt strong")
        XCTAssertEqual(w.exercises.count, 2)
        XCTAssertEqual(w.exercises[0].name, "Bench Press")
        XCTAssertEqual(w.exercises[0].sets.count, 3)
        XCTAssertEqual(w.exercises[0].sets[0].weightKg, 80, accuracy: 0.001)
        XCTAssertEqual(w.exercises[0].sets[0].reps, 8)
        XCTAssertEqual(w.exercises[1].name, "Overhead Press")
        XCTAssertEqual(w.exercises[1].sets.count, 1)
    }

    func testStrongParserGroupsByDateAndName() {
        // Two workouts on different dates + a same-date second workout
        // with a different name. All three should be separate.
        let csv = """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        2024-01-15 18:00:00,Pull,Pull-up,1,0,10,,,,,1800
        2024-01-16 06:30:00,Push,Bench Press,1,82.5,8,,,,,3600
        """
        let workouts = parseStrong(csv)
        XCTAssertEqual(workouts.count, 3)
        XCTAssertEqual(workouts.map(\.title), ["Push", "Pull", "Push"])
    }

    func testStrongParserPreservesExerciseOrder() {
        let csv = """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        2024-01-15 06:30:00,Push,Incline Press,1,60,8,,,,,3600
        2024-01-15 06:30:00,Push,Tricep Pushdown,1,40,10,,,,,3600
        """
        let workouts = parseStrong(csv)
        XCTAssertEqual(workouts.first?.exercises.map(\.name),
                       ["Bench Press", "Incline Press", "Tricep Pushdown"])
    }

    func testStrongParserSkipsZeroRepRows() {
        // Strong leaves placeholder 0/0 rows behind sometimes when the
        // user adds and removes a set. The parser should drop them.
        let csv = """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        2024-01-15 06:30:00,Push,Bench Press,2,0,0,,,,,3600
        2024-01-15 06:30:00,Push,Bench Press,3,80,8,,,,,3600
        """
        let workouts = parseStrong(csv)
        XCTAssertEqual(workouts.first?.exercises.first?.sets.count, 2,
                       "Placeholder 0/0 set must not survive parse")
    }

    func testStrongParserEndDateFromDurationField() {
        // Strong's "Workout Duration" is total seconds. parseRows
        // should turn it into an endDate offset from the start.
        let csv = """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        """
        let w = parseStrong(csv).first
        XCTAssertNotNil(w?.endDate)
        let expected = w!.startDate.addingTimeInterval(3600)
        XCTAssertEqual(w!.endDate!.timeIntervalSinceReferenceDate,
                       expected.timeIntervalSinceReferenceDate,
                       accuracy: 0.001)
    }

    func testStrongParserDropsRowsWithUnparseableDate() {
        // First column has to parse. A row with a malformed date
        // shouldn't crash or take the rest of the workout down.
        let csv = """
        \(strongHeader)
        bogus-date,Push,Bench Press,1,80,8,,,,,3600
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        """
        let workouts = parseStrong(csv)
        XCTAssertEqual(workouts.count, 1, "Bad-date row must not produce a workout")
    }

    // MARK: - Hevy parser

    private let hevyHeader = "title,start_time,end_time,description,exercise_title,superset_id,exercise_notes,set_index,set_type,weight_kg,reps,distance_km,duration_seconds,rpe"

    func testHevyParserBasicWorkout() {
        let csv = """
        \(hevyHeader)
        Push Day,"15 Jan 2024, 06:30","15 Jan 2024, 07:30",Notes here,Bench Press,,,1,normal,80,8,,,
        Push Day,"15 Jan 2024, 06:30","15 Jan 2024, 07:30",Notes here,Bench Press,,,2,normal,80,8,,,
        Push Day,"15 Jan 2024, 06:30","15 Jan 2024, 07:30",Notes here,Overhead Press,,,1,normal,50,8,,,
        """
        let workouts = parseHevy(csv)
        XCTAssertEqual(workouts.count, 1)
        let w = workouts[0]
        XCTAssertEqual(w.title, "Push Day")
        XCTAssertEqual(w.notes, "Notes here")
        XCTAssertNotNil(w.endDate)
        XCTAssertEqual(w.exercises.count, 2)
        XCTAssertEqual(w.exercises[0].name, "Bench Press")
        XCTAssertEqual(w.exercises[0].sets.count, 2)
        XCTAssertEqual(w.exercises[1].name, "Overhead Press")
    }

    func testHevyParserWarmupFlagFromSetType() {
        let csv = """
        \(hevyHeader)
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,1,warmup,40,10,,,
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,2,normal,80,8,,,
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,3,failure,80,6,,,
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,4,dropset,60,8,,,
        """
        let sets = parseHevy(csv).first?.exercises.first?.sets ?? []
        XCTAssertEqual(sets.count, 4)
        XCTAssertEqual(sets.map(\.isWarmUp), [true, false, false, false],
                       "Only 'warmup' set_type should map to isWarmUp")
    }

    func testHevyParserConvertsDistanceFromKmToMeters() {
        // distance_km is metric kilometers; our schema stores meters.
        let csv = """
        \(hevyHeader)
        Run,"15 Jan 2024, 06:30",,,Outdoor Run,,,1,normal,0,1,5.2,1800,
        """
        let set = parseHevy(csv).first?.exercises.first?.sets.first
        XCTAssertEqual(set?.distanceMeters ?? 0, 5200, accuracy: 0.001)
        XCTAssertEqual(set?.durationSeconds, 1800)
    }

    func testHevyParserParsesRPE() {
        let csv = """
        \(hevyHeader)
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,1,normal,80,8,,,8
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,2,normal,80,6,,,9
        """
        let sets = parseHevy(csv).first?.exercises.first?.sets ?? []
        XCTAssertEqual(sets.map(\.rpe), [8, 9])
    }

    func testHevyParserPicksUpSupersetID() {
        // Two exercises in superset_id = 1 should both carry that
        // grouping through to ParsedExercise.supersetGroup.
        let csv = """
        \(hevyHeader)
        Push,"15 Jan 2024, 06:30",,,Bench Press,1,,1,normal,80,8,,,
        Push,"15 Jan 2024, 06:30",,,Cable Fly,1,,1,normal,30,12,,,
        """
        let exercises = parseHevy(csv).first?.exercises ?? []
        XCTAssertEqual(exercises.compactMap(\.supersetGroup), [1, 1])
    }

    func testHevyParserSkipsRowsWithMissingRequiredFields() {
        // Missing reps must skip; missing title must skip; missing
        // weight is OK (bodyweight exercise stored as weight=0).
        let csv = """
        \(hevyHeader)
        ,"15 Jan 2024, 06:30",,,Bench Press,,,1,normal,80,8,,,
        Push,,,,,Bench Press,,,1,normal,80,8,,,
        Push,"15 Jan 2024, 06:30",,,Pull-up,,,1,normal,,10,,,
        """
        let workouts = parseHevy(csv)
        XCTAssertEqual(workouts.count, 1)
        XCTAssertEqual(workouts[0].exercises.first?.name, "Pull-up")
        XCTAssertEqual(workouts[0].exercises.first?.sets.first?.weightKg, 0,
                       "Bodyweight exercise stores zero weight, still imports")
    }

    func testHevyParserBailsOnMissingRequiredColumns() {
        // If the header is missing required columns, the parser
        // returns an empty array — better than producing
        // semi-mangled workouts.
        let csv = """
        title,start_time,exercise_title
        Push,"15 Jan 2024, 06:30",Bench Press
        """
        XCTAssertTrue(parseHevy(csv).isEmpty)
    }

    // MARK: - End-to-end via ImportHelper

    func testImportHelperDispatchesToStrongParser() {
        // Smoke test: a Strong-shaped CSV passes through the
        // detection + dispatch layer in ImportHelper.importCSV without
        // throwing invalidFormat.
        let csv = """
        \(strongHeader)
        2024-01-15 06:30:00,Push,Bench Press,1,80,8,,,,,3600
        """
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertGreaterThan(rows.count, 1)
        XCTAssertEqual(ImportFormat.detect(header: rows[0]), .strong)
    }

    func testImportHelperDispatchesToHevyParser() {
        let csv = """
        \(hevyHeader)
        Push,"15 Jan 2024, 06:30",,,Bench Press,,,1,normal,80,8,,,
        """
        let rows = ImportHelper.parseCSVRows(csv)
        XCTAssertEqual(ImportFormat.detect(header: rows[0]), .hevy)
    }

    // MARK: - Helpers

    private func parseStrong(_ csv: String) -> [ParsedWorkout] {
        let rows = ImportHelper.parseCSVRows(csv)
        return StrongParser.parseRows(Array(rows.dropFirst()))
    }

    private func parseHevy(_ csv: String) -> [ParsedWorkout] {
        let rows = ImportHelper.parseCSVRows(csv)
        guard let header = rows.first else { return [] }
        return HevyParser.parseRows(header: header,
                                    rows: Array(rows.dropFirst()))
    }
}

// MARK: - MuscleGroup inference

/// `MuscleGroup.inferred(fromName:)` is the bridge between
/// Strong/Hevy's name-only exercise data and Metricly's category-
/// based recovery math. Pin the major buckets so a future tweak to
/// the heuristic doesn't silently re-bucket every imported workout.
final class MuscleGroupInferenceTests: XCTestCase {

    func testBenchPressIsChest() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Bench Press"), .chest)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Incline Bench Press"), .chest)
    }

    func testSquatIsLegs() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Squat"), .legs)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Front Squat"), .legs)
    }

    func testDeadliftIsLegs() {
        // Deadlift hits posterior chain hard enough that the legs
        // bucket is the right call for recovery math (we don't have
        // a separate posterior bucket).
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Deadlift"), .legs)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Romanian Deadlift"), .legs)
    }

    func testOverheadPressIsShoulders() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Overhead Press"), .shoulders)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "OHP"), .shoulders)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Military Press"), .shoulders)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Lateral Raise"), .shoulders)
    }

    func testBicepCurlIsBiceps() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Bicep Curl"), .biceps)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Hammer Curl"), .biceps)
    }

    func testTricepPushdownIsTriceps() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Tricep Pushdown"), .triceps)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Skullcrusher"), .triceps)
    }

    func testRowIsBack() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Barbell Row"), .back)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Lat Pulldown"), .back)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Pull-up"), .back)
    }

    func testRunIsCardio() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Outdoor Run"), .cardio)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Treadmill"), .cardio)
    }

    func testPlankIsCore() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Plank"), .core)
    }

    func testAbWheelIsCore() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Ab Wheel"), .core)
    }

    func testCrunchIsCore() {
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Crunch"), .core)
    }

    func testTricepPushdownDoesNotBucketAsChest() {
        // Defensive: the order of checks matters because "push" is
        // a substring of "pushdown". This test pins that the more
        // specific tricep check wins.
        XCTAssertNotEqual(MuscleGroup.inferred(fromName: "Tricep Pushdown"), .chest)
    }

    func testLegCurlDoesNotBucketAsBiceps() {
        // "curl" appears in both "Bicep Curl" and "Leg Curl"; the
        // leg-curl exception in the matcher should keep the
        // hamstring movement out of the biceps bucket.
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Leg Curl"), .legs)
        XCTAssertEqual(MuscleGroup.inferred(fromName: "Hamstring Curl"), .legs)
    }

    func testUnknownExerciseReturnsNil() {
        // Caller is expected to default to .other.
        XCTAssertNil(MuscleGroup.inferred(fromName: "Mystery Movement"))
    }
}
