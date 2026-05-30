import XCTest
@testable import tracker

/// Tests for `PersonalInsightsEngine.blockPhaseVsPerformance` —
/// the periodisation-quality insight that compares user e1RM during
/// accumulate blocks vs deload blocks.
///
/// The whole insight exists to answer "is your periodisation
/// actually working?", so the tests focus on three contracts:
///
///   1. **Bucketing.** A workout falling inside an accumulate block
///      must land in the accumulate bucket; same for deload. Workouts
///      in a gap (between blocks) drop out of the comparison.
///   2. **Sample floors.** The insight only fires once each bucket
///      has ≥3 sessions of the dominant exercise — small samples
///      produce noisy comparisons.
///   3. **Effect floor + direction.** Below the engine's
///      `minEffectPct` the insight stays silent. The title flips
///      based on direction (accumulate > deload reads as "blocks
///      are working"; the reverse warns the accumulate is too long).
@MainActor
final class BlockPhaseInsightTests: XCTestCase {

    // MARK: - Helpers

    private let cal = Calendar.current

    /// Deterministic anchor far enough back that the engine's
    /// 90-day "wide" lookback still contains all our fixture dates.
    private static let now: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 4; c.day = 1
        return Calendar.current.date(from: c) ?? .distantPast
    }()

    private func day(daysAgo: Int) -> Date {
        cal.date(byAdding: .day, value: -daysAgo, to: BlockPhaseInsightTests.now)
            ?? BlockPhaseInsightTests.now
    }

    /// One workout with N sets of the same exercise at a given weight.
    /// Naming everything "Bench Press" makes that the dominant
    /// exercise across the fixture set — `topExerciseName` returns it
    /// and the engine's per-exercise filter focuses on those sets.
    private func benchWorkout(daysAgo: Int, weight: Double, reps: Int = 5) -> Workout {
        let date = day(daysAgo: daysAgo)
        let w = Workout(name: "Push", date: date)
        w.endTime = date.addingTimeInterval(3600)
        let ex = Exercise(name: "Bench Press", workout: w, category: .chest)
        for _ in 0..<3 {
            let s = ExerciseSet(reps: reps, weight: weight, exercise: ex)
            ex.sets.append(s)
        }
        w.exercises.append(ex)
        return w
    }

    private func block(startedDaysAgo: Int, weeks: Int, phase: TrainingBlock.Phase) -> TrainingBlock {
        TrainingBlock(startDate: day(daysAgo: startedDaysAgo), weekCount: weeks, phase: phase)
    }

    /// Engine call shorthand pinned to the same `now` the fixtures use.
    private func generate(
        workouts: [Workout],
        blocks: [TrainingBlock]
    ) -> [Insight] {
        let inputs = PersonalInsightsEngine.Inputs(
            workouts: workouts,
            trainingBlocks: blocks,
            now: BlockPhaseInsightTests.now
        )
        return PersonalInsightsEngine.generate(inputs)
    }

    private func extract(_ insights: [Insight]) -> Insight? {
        insights.first { $0.category == .performance && $0.icon == "calendar.badge.clock" }
    }

    // MARK: - Bucketing

    func testAccumulateBeatsDeloadProducesWorkingNarrative() {
        // 4-week accumulate ending 28 days ago, then 1-week deload
        // ending 21 days ago, then another 4-week accumulate ending
        // today. Three bench sessions per block at the listed weights
        // — accumulate weeks at 100kg, deload at 85kg. Engine should
        // surface "Your blocks are working" + a ~17% diff.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
            block(startedDaysAgo: 21, weeks: 3, phase: .accumulate),
        ]
        var workouts: [Workout] = []
        // Accumulate window 1 — days 56...29
        for offset in [40, 36, 32, 50] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        // Deload window — days 28...22
        for offset in [27, 25, 23] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 85))
        }
        // Accumulate window 2 — days 21...1
        for offset in [18, 14, 7, 3] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }

        let insight = extract(generate(workouts: workouts, blocks: blocks))
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Your blocks are working")
        XCTAssertTrue(insight?.message.contains("higher during accumulation") == true,
                      "Message should attribute strength to accumulation. Got: \(insight?.message ?? "nil")")
    }

    func testDeloadBeatsAccumulateProducesOverreachWarning() {
        // Inverse direction — deload weeks read STRONGER than
        // accumulate. That's the "accumulate is too long" pattern; the
        // insight should warn rather than congratulate.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
            block(startedDaysAgo: 21, weeks: 3, phase: .accumulate),
        ]
        var workouts: [Workout] = []
        for offset in [40, 36, 32, 50] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 85))
        }
        for offset in [27, 25, 23] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        for offset in [18, 14, 7, 3] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 85))
        }

        let insight = extract(generate(workouts: workouts, blocks: blocks))
        XCTAssertNotNil(insight)
        XCTAssertEqual(insight?.title, "Accumulation is wearing you down")
        XCTAssertTrue(insight?.message.contains("Consider shortening") == true,
                      "Message should suggest shorter accumulate. Got: \(insight?.message ?? "nil")")
    }

    func testWorkoutsInGapsAreIgnored() {
        // Two blocks separated by a 10-day gap. Sessions during the
        // gap fall into NEITHER bucket. With only 2 sessions per
        // bucket, the insight should NOT fire (below sample floor),
        // confirming the gap sessions weren't snuck in to either side.
        let blocks = [
            block(startedDaysAgo: 60, weeks: 4, phase: .accumulate),  // 60...32
            block(startedDaysAgo: 20, weeks: 1, phase: .deload),      // 20...13
        ]
        var workouts: [Workout] = []
        // Accumulate (2 sessions — below floor)
        for offset in [50, 40] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        // Gap days (28-21) — should be ignored
        for offset in [27, 25, 22] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 85))
        }
        // Deload (2 sessions — below floor)
        for offset in [18, 14] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 85))
        }

        XCTAssertNil(extract(generate(workouts: workouts, blocks: blocks)),
                     "Gap sessions must not pad either bucket — insight should stay below floor")
    }

    // MARK: - Sample floors

    func testEmptyBlocksProducesNoInsight() {
        // No periodisation history → no block insight, even with
        // plenty of lifting data.
        var workouts: [Workout] = []
        for offset in 1...10 {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        XCTAssertNil(extract(generate(workouts: workouts, blocks: [])))
    }

    func testTooFewAccumulateSessionsProducesNoInsight() {
        // Two accumulate sessions (below the 3-session floor), four
        // deload sessions. Even with the deload bucket safely above
        // floor, the insight must hold back because one side is too
        // thin to support a comparison — better silence than a
        // misleading 2-vs-4 read.
        let blocks = [
            block(startedDaysAgo: 60, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
        ]
        var workouts: [Workout] = []
        for offset in [50, 40] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        for offset in [27, 25, 23, 22] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 85))
        }
        XCTAssertNil(
            extract(generate(workouts: workouts, blocks: blocks)),
            "Accumulate bucket below floor — insight should stay silent regardless of deload count"
        )
    }

    // MARK: - Effect floor

    func testTinyDifferenceFallsBelowEffectFloor() {
        // Both buckets at the same weight → 0% diff, well below the
        // engine's minimum-effect threshold. No insight.
        let blocks = [
            block(startedDaysAgo: 56, weeks: 4, phase: .accumulate),
            block(startedDaysAgo: 28, weeks: 1, phase: .deload),
            block(startedDaysAgo: 21, weeks: 3, phase: .accumulate),
        ]
        var workouts: [Workout] = []
        for offset in [40, 36, 32, 50] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        for offset in [27, 25, 23] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        for offset in [18, 14, 7, 3] {
            workouts.append(benchWorkout(daysAgo: offset, weight: 100))
        }
        XCTAssertNil(extract(generate(workouts: workouts, blocks: blocks)),
                     "Zero-diff comparison must not surface as an insight")
    }
}
