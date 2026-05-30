import XCTest
import SwiftData
@testable import tracker

/// Tests for the Sprint 30 adaptive-training-block feature. Four
/// layers covered:
///   1. **Model.** `TrainingBlock` containment, weekIndex math,
///       phase round-trip through raw storage, clamping at init.
///   2. **Engine resolution.** `currentBlock(at:)`,
///      `mostRecentlyEnded(before:)`, `progressLabel`.
///   3. **Engine advancement.** `recommend(from:at:)` — bootstrap
///      from empty history, alternation between phases, and the
///      "active block still running" guard on `shouldRecommendNow`.
///   4. **TodayPlanEngine integration.** A `.deload` block caps a
///      `.hard`/`.moderate` recovery call at `.light`; an
///      `.accumulate` block doesn't change intensity; `.rest` is
///      never promoted to `.light`.
final class TrainingBlockTests: XCTestCase {

    // MARK: - Helpers

    private let cal = Calendar.current

    /// Build a deterministic date — offsets from a fixed anchor so
    /// no test depends on `.now` and DST/midnight surprises don't
    /// flake. The anchor is mid-month / mid-year on purpose.
    private func day(_ offsetDays: Int) -> Date {
        cal.date(byAdding: .day, value: offsetDays, to: TrainingBlockTests.anchor)
            ?? TrainingBlockTests.anchor
    }

    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 15
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? .distantPast
    }()

    // MARK: - Model

    func testInitClampsWeekCount() {
        // Defensive clamps at construction — caller passing 0 or 100
        // weeks (e.g. from a UI bug) shouldn't break the engine.
        XCTAssertEqual(TrainingBlock(startDate: .now, weekCount: 0, phase: .accumulate).weekCount, 1)
        XCTAssertEqual(TrainingBlock(startDate: .now, weekCount: -5, phase: .accumulate).weekCount, 1)
        XCTAssertEqual(TrainingBlock(startDate: .now, weekCount: 100, phase: .accumulate).weekCount, 12)
    }

    func testStartDateNormalisedToStartOfDay() {
        // The init normalises the start so duration math doesn't
        // shift by a fraction-of-a-day on DST/midnight boundaries.
        let withTime = day(0)   // anchor is 09:00
        let block = TrainingBlock(startDate: withTime, weekCount: 4, phase: .accumulate)
        let dayPart = cal.startOfDay(for: withTime)
        XCTAssertEqual(block.startDate, dayPart)
    }

    func testContainsIsHalfOpenInterval() {
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        // Inside on the start day
        XCTAssertTrue(block.contains(day(0)))
        // Inside on the last day of the block (day 27 of a 4-week block)
        XCTAssertTrue(block.contains(day(27)))
        // OUTSIDE on the exclusive end (day 28 = first day of next block)
        XCTAssertFalse(block.contains(day(28)))
        // Outside before start
        XCTAssertFalse(block.contains(day(-1)))
    }

    func testWeekIndexBucketing() {
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        XCTAssertEqual(block.weekIndex(at: day(0)), 1)   // day 0 = week 1
        XCTAssertEqual(block.weekIndex(at: day(6)), 1)   // end of week 1
        XCTAssertEqual(block.weekIndex(at: day(7)), 2)   // start of week 2
        XCTAssertEqual(block.weekIndex(at: day(21)), 4)  // start of week 4
        XCTAssertNil(block.weekIndex(at: day(28)))       // outside the block
    }

    func testPhaseRoundTripsThroughRaw() {
        // Defensive read: even if `phaseRaw` were corrupted to an
        // unknown value, `phase` should fall back rather than crash.
        let block = TrainingBlock(startDate: .now, weekCount: 4, phase: .deload)
        XCTAssertEqual(block.phase, .deload)
        block.phaseRaw = "garbage_value"
        XCTAssertEqual(block.phase, .accumulate, "Unknown raw values fall back to accumulate")
    }

    // MARK: - Engine resolution

    func testCurrentBlockFindsContainingBlock() {
        let b1 = TrainingBlock(startDate: day(0),  weekCount: 4, phase: .accumulate)
        let b2 = TrainingBlock(startDate: day(28), weekCount: 1, phase: .deload)
        XCTAssertEqual(TrainingBlockEngine.currentBlock(in: [b1, b2], at: day(10))?.phase, .accumulate)
        XCTAssertEqual(TrainingBlockEngine.currentBlock(in: [b1, b2], at: day(30))?.phase, .deload)
    }

    func testCurrentBlockReturnsNilInGap() {
        let b1 = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        // The block ends at day 28; day 30 falls in a gap with no
        // active block. The engine should return nil rather than the
        // most recently ended.
        XCTAssertNil(TrainingBlockEngine.currentBlock(in: [b1], at: day(30)))
    }

    func testMostRecentlyEndedBeforeDate() {
        let b1 = TrainingBlock(startDate: day(0),  weekCount: 1, phase: .accumulate)  // ends day 7
        let b2 = TrainingBlock(startDate: day(20), weekCount: 1, phase: .deload)      // ends day 27
        // At day 30 b2 is the most recently ended.
        XCTAssertEqual(TrainingBlockEngine.mostRecentlyEnded(in: [b1, b2], before: day(30))?.phase, .deload)
        // At day 10 only b1 has ended.
        XCTAssertEqual(TrainingBlockEngine.mostRecentlyEnded(in: [b1, b2], before: day(10))?.phase, .accumulate)
    }

    func testProgressLabel() {
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        XCTAssertEqual(TrainingBlockEngine.progressLabel(for: block, at: day(7)), "Week 2 of 4")
        XCTAssertNil(TrainingBlockEngine.progressLabel(for: block, at: day(40)),
                     "Outside the block: no label")
    }

    // MARK: - Engine advancement

    func testRecommendFromEmptyHistoryBootstrapsAccumulate() {
        let rec = TrainingBlockEngine.recommend(from: [], at: day(0))
        XCTAssertEqual(rec.nextPhase, .accumulate)
        XCTAssertEqual(rec.nextWeekCount, 4)
        XCTAssertTrue(rec.shouldRecommendNow)
    }

    func testRecommendAfterAccumulateSuggestsDeload() {
        let b1 = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        // At day 30 the accumulate has ended; nothing's active.
        let rec = TrainingBlockEngine.recommend(from: [b1], at: day(30))
        XCTAssertEqual(rec.nextPhase, .deload)
        XCTAssertEqual(rec.nextWeekCount, 1)
        XCTAssertTrue(rec.shouldRecommendNow)
    }

    func testRecommendAfterDeloadSuggestsAccumulate() {
        let b1 = TrainingBlock(startDate: day(0),  weekCount: 4, phase: .accumulate)
        let b2 = TrainingBlock(startDate: day(28), weekCount: 1, phase: .deload)
        // At day 40 the deload has ended.
        let rec = TrainingBlockEngine.recommend(from: [b1, b2], at: day(40))
        XCTAssertEqual(rec.nextPhase, .accumulate)
        XCTAssertEqual(rec.nextWeekCount, 4)
        XCTAssertTrue(rec.shouldRecommendNow)
    }

    func testRecommendWhileActiveDoesNotNudge() {
        let b1 = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        // Mid-block — the next recommendation exists (deload) but
        // shouldRecommendNow stays false so the UI doesn't pester.
        let rec = TrainingBlockEngine.recommend(from: [b1], at: day(10))
        XCTAssertFalse(rec.shouldRecommendNow,
                       "Mid-block: shouldn't surface a follow-on nudge")
        XCTAssertEqual(rec.nextPhase, .deload,
                       "The shape of the next block is still computed though")
    }

    // MARK: - TodayPlanEngine integration

    /// A high recovery score that would otherwise produce `.hard`,
    /// to confirm the block cap actually overrides recovery.
    private let highRecovery = RecoveryResult(
        readinessScore: 0.90,
        muscleResults: [],
        suggestedWorkoutType: "Anything"
    )

    /// A recovery score below the rest threshold so we can verify
    /// `.rest` is never promoted by a block.
    private let restRecovery = RecoveryResult(
        readinessScore: 0.20,
        muscleResults: [],
        suggestedWorkoutType: "Rest day"
    )

    func testDeloadBlockCapsIntensityAtLight() {
        let block = TrainingBlock(startDate: day(0), weekCount: 1, phase: .deload)
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: highRecovery,
            health: HealthSignals(),
            alreadyTrainedToday: false,
            currentBlock: block,
            now: day(2)   // inside the deload window
        )
        XCTAssertEqual(plan.intensity, .light,
                       "Deload caps high-recovery .hard down to .light")
    }

    func testAccumulateBlockDoesNotChangeIntensity() {
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: highRecovery,
            health: HealthSignals(),
            alreadyTrainedToday: false,
            currentBlock: block,
            now: day(2)
        )
        XCTAssertEqual(plan.intensity, .hard,
                       "Accumulate leaves intensity unchanged from the recovery call")
    }

    func testDeloadDoesNotPromoteRest() {
        let block = TrainingBlock(startDate: day(0), weekCount: 1, phase: .deload)
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: restRecovery,
            health: HealthSignals(),
            alreadyTrainedToday: false,
            currentBlock: block,
            now: day(2)
        )
        XCTAssertEqual(plan.intensity, .rest,
                       ".rest is sacred — deload doesn't promote it back to .light")
    }

    func testBlockReasonLineSurfacedDuringAccumulate() {
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: highRecovery,
            health: HealthSignals(),
            alreadyTrainedToday: false,
            currentBlock: block,
            now: day(7)   // week 2 of 4
        )
        XCTAssertTrue(
            plan.reasons.contains(where: { $0.lowercased().contains("week 2 of 4") }),
            "Accumulate block should surface 'Week 2 of 4' in reasons. Got: \(plan.reasons)"
        )
    }

    func testNilBlockBehavesLikeV4() {
        // Sanity: passing nil currentBlock leaves the engine unchanged
        // from its V4 behaviour. Intensity should match what the
        // recovery score dictates with no override.
        let plan = TodayPlanEngine.generate(
            scheduledName: nil,
            recovery: highRecovery,
            health: HealthSignals(),
            alreadyTrainedToday: false,
            currentBlock: nil
        )
        XCTAssertEqual(plan.intensity, .hard)
        XCTAssertFalse(plan.reasons.contains(where: { $0.lowercased().contains("block") }),
                       "No block context → no periodisation reason line")
    }
}
