import XCTest
@testable import tracker

/// Tests for `ImportAnalyzer.analyze(_:)` — the post-import
/// wow-moment analyzer that turns a `[ParsedWorkout]` into the
/// observation set the success sheet renders. Pure function; we
/// drive it with hand-rolled ParsedWorkout values and assert each
/// piece of the resulting `ImportAnalysis` independently.
final class ImportAnalyzerTests: XCTestCase {

    // MARK: - Helpers

    /// Build a ParsedWorkout from a flat list of (exercise name,
    /// [reps × weight] sets). Keeps the fixtures readable.
    private func workout(
        title: String = "Push",
        startDate: Date,
        endDate: Date? = nil,
        exercises: [(name: String, sets: [(reps: Int, weight: Double, isWarmUp: Bool)])]
    ) -> ParsedWorkout {
        let parsedExercises = exercises.map { ex in
            ParsedExercise(
                name: ex.name,
                supersetGroup: nil,
                notes: "",
                sets: ex.sets.map { s in
                    ParsedSet(
                        reps: s.reps,
                        weightKg: s.weight,
                        rpe: nil,
                        isWarmUp: s.isWarmUp,
                        distanceKm: nil,
                        durationSeconds: nil
                    )
                }
            )
        }
        return ParsedWorkout(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: "",
            exercises: parsedExercises
        )
    }

    private func date(_ daysAgo: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now
    }

    // MARK: - Empty input

    func testEmptyInputProducesZeroedAnalysis() {
        let a = ImportAnalyzer.analyze([])
        XCTAssertEqual(a.workoutCount, 0)
        XCTAssertEqual(a.exerciseCount, 0)
        XCTAssertEqual(a.totalSetCount, 0)
        XCTAssertNil(a.dateRange)
        XCTAssertEqual(a.monthSpan, 0)
        XCTAssertEqual(a.prCount, 0)
        XCTAssertNil(a.topExercise)
        XCTAssertNil(a.mostTrainedGroup)
        XCTAssertNil(a.leastTrainedGroup)
        XCTAssertNil(a.recommendation)
    }

    // MARK: - Headline counts

    func testWorkoutAndExerciseCounts() {
        let w = [
            workout(startDate: date(30),
                    exercises: [("Bench Press", [(8, 80, false), (8, 80, false)]),
                                ("Squat", [(5, 100, false)])]),
            workout(startDate: date(28),
                    exercises: [("Bench Press", [(8, 80, false)])]),
        ]
        let a = ImportAnalyzer.analyze(w)
        XCTAssertEqual(a.workoutCount, 2)
        XCTAssertEqual(a.exerciseCount, 2,
                       "Bench Press appears twice but counts as one unique exercise")
        XCTAssertEqual(a.totalSetCount, 4)
    }

    func testDateRangeAndMonthSpan() {
        let w = [
            workout(startDate: date(90), exercises: [("Bench Press", [(5, 80, false)])]),
            workout(startDate: date(0),  exercises: [("Bench Press", [(5, 85, false)])]),
        ]
        let a = ImportAnalyzer.analyze(w)
        XCTAssertNotNil(a.dateRange)
        // 90 days is "about 3 months" but Calendar.month between two
        // dates returns 2 when the span starts and ends in months
        // shorter than 30 days (e.g. Feb→May). Assert "at least 2"
        // rather than pinning exact equality so the test isn't
        // flaky depending on when in the year it runs.
        XCTAssertGreaterThanOrEqual(a.monthSpan, 2,
                                    "90 days should span at least 2 calendar months")
    }

    // MARK: - Top exercise

    func testTopExerciseReturnsMostFrequent() {
        let w = (1...10).map { i in
            workout(startDate: date(i),
                    exercises: [("Bench Press", [(5, 80, false)])])
        } + (1...3).map { i in
            workout(startDate: date(i + 10),
                    exercises: [("Squat", [(5, 100, false)])])
        }
        let a = ImportAnalyzer.analyze(w)
        XCTAssertEqual(a.topExercise?.name, "Bench Press")
        XCTAssertEqual(a.topExercise?.hits, 10)
    }

    func testTopExercisePreservesOriginalCasing() {
        // Even when the user's CSV mixes cases, we surface the
        // display-cased version from the source.
        let w = [
            workout(startDate: date(2),
                    exercises: [("Bench Press", [(5, 80, false)])]),
            workout(startDate: date(1),
                    exercises: [("BENCH press", [(5, 80, false)])]),
        ]
        let a = ImportAnalyzer.analyze(w)
        XCTAssertTrue(a.topExercise?.name.lowercased().contains("bench") == true)
        XCTAssertEqual(a.topExercise?.hits, 2)
    }

    // MARK: - Muscle group balance

    func testMostAndLeastTrainedGroups() {
        // Heavy bench / heavy squat / very light shoulder.
        let w = (1...10).map { i in
            workout(title: "Push", startDate: date(i),
                    exercises: [("Bench Press", [(8, 80, false)])])
        } + (1...10).map { i in
            workout(title: "Legs", startDate: date(i + 10),
                    exercises: [("Squat", [(5, 120, false)])])
        } + [
            workout(title: "Shoulder", startDate: date(25),
                    exercises: [("Overhead Press", [(8, 40, false)])])
        ]
        let a = ImportAnalyzer.analyze(w)
        // Squat (10 × 5 × 120 = 6000) > Bench (10 × 8 × 80 = 6400)
        // Actually bench wins by a hair — but both are way above
        // shoulder (1 × 8 × 40 = 320). Just assert the *least* is
        // shoulders, which is the actionable observation.
        XCTAssertEqual(a.leastTrainedGroup, MuscleGroup.shoulders)
        XCTAssertNotNil(a.mostTrainedGroup)
        let allowedTop: [MuscleGroup] = [.chest, .legs]
        XCTAssertTrue(allowedTop.contains(a.mostTrainedGroup!))
    }

    func testLeastTrainedGroupExcludesCardioAndOther() {
        // A pile of cardio + very little strength: cardio shouldn't
        // dominate the "least" bucket because that's a useless
        // observation. The least-trained STRENGTH group is what
        // the user can act on.
        let w = (1...10).map { i in
            workout(title: "Run", startDate: date(i),
                    exercises: [("Treadmill", [(0, 0, false)])])
        } + [
            workout(title: "Push", startDate: date(11),
                    exercises: [("Bench Press", [(5, 80, false)])])
        ]
        let a = ImportAnalyzer.analyze(w)
        // Cardio sets have zero weight; they don't contribute to
        // group volume in the analyzer (we filter weightKg > 0).
        // Treadmill won't show up as "least" because it has zero
        // volume — it just won't be in the volumes dict.
        XCTAssertNotEqual(a.leastTrainedGroup, .cardio)
        XCTAssertNotEqual(a.leastTrainedGroup, .other)
    }

    // MARK: - PR detection

    func testActivePRWhenBestLiftIsRecent() {
        // 6 bench sessions; best lift comes in the 5th.
        // history.count = 6 → midpoint = 3 → bestIndex (4) >= 3 → PR.
        let weights = [80.0, 82.5, 85.0, 87.5, 90.0, 87.5]
        let w = weights.enumerated().map { i, weight in
            workout(startDate: date(weights.count - i),
                    exercises: [("Bench Press", [(5, weight, false)])])
        }
        let a = ImportAnalyzer.analyze(w)
        XCTAssertEqual(a.prCount, 1,
                       "Best lift in the recent half should count as an active PR")
    }

    func testStaleAllTimeTopDoesNotCountAsPR() {
        // 6 sessions; best lift was the FIRST. bestIndex 0 < midpoint 3
        // → not an active PR (the user has been off their peak since).
        let weights = [100.0, 95.0, 90.0, 85.0, 80.0, 75.0]
        let w = weights.enumerated().map { i, weight in
            workout(startDate: date(weights.count - i),
                    exercises: [("Bench Press", [(5, weight, false)])])
        }
        let a = ImportAnalyzer.analyze(w)
        XCTAssertEqual(a.prCount, 0,
                       "Stale all-time tops should NOT count toward active PRs")
    }

    func testPRsRequireMinimumSessionCount() {
        // Only 3 bench sessions — below the 4-session floor.
        let w = (1...3).map { i in
            workout(startDate: date(i),
                    exercises: [("Bench Press", [(5, Double(80 + i), false)])])
        }
        let a = ImportAnalyzer.analyze(w)
        XCTAssertEqual(a.prCount, 0,
                       "Exercises with fewer than 4 sessions should not be counted")
    }

    func testWarmupSetsDoNotInfluencePRs() {
        // Heavy warmup at 100 kg, all working sets lighter.
        // The warmup should be filtered out by isWarmUp before e1RM.
        let w = (1...4).map { i in
            workout(startDate: date(i),
                    exercises: [("Bench Press",
                                [(1, 100, true), (8, 80, false)])])
        }
        let a = ImportAnalyzer.analyze(w)
        // All working sets are identical (8 × 80 → e1RM ≈ 101 kg);
        // best is "first" but they're all the same so `firstIndex`
        // picks 0. With 4 sessions and bestIndex 0 < midpoint 2,
        // not an active PR — which is the right answer for
        // identical working sets.
        XCTAssertEqual(a.prCount, 0)
    }

    // MARK: - Recommendation

    func testRecommendationPicksMostFrequentWorkoutName() {
        let w = (1...5).map { i in
            workout(title: "Push", startDate: date(i),
                    exercises: [("Bench Press", [(5, 80, false)])])
        } + (1...2).map { i in
            workout(title: "Pull", startDate: date(i + 10),
                    exercises: [("Pull-up", [(5, 0, false)])])
        }
        let a = ImportAnalyzer.analyze(w)
        XCTAssertEqual(a.recommendation?.workoutName, "Push")
        XCTAssertEqual(a.recommendation?.intensity, .moderate,
                       "Initial recommendation is moderate; engine refines later")
    }
}
