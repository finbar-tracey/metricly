import XCTest
import SwiftData
@testable import tracker

/// Tests for `TrainingBlockApply` — the mutation layer the detail
/// sheet calls into. Two surfaces:
///
///   1. **endEarly.** Truncates `weekCount` so the block ends at the
///      end of `now`'s day. Must produce a still-valid block
///      (`weekCount >= 1`) and must make the block's containment
///      check stop returning true the day after `now`.
///   2. **startNext.** Inserts a new block matching the engine's
///      recommendation. The new block's phase / week-count must
///      match `TrainingBlockEngine.recommend(from:at:)` for the
///      same inputs.
@MainActor
final class TrainingBlockApplyTests: XCTestCase {

    private let cal = Calendar.current

    /// Deterministic anchor — same shape as `TrainingBlockTests`.
    private static let anchor: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 3; c.day = 15
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? .distantPast
    }()

    private func day(_ offset: Int) -> Date {
        cal.date(byAdding: .day, value: offset, to: TrainingBlockApplyTests.anchor)
            ?? TrainingBlockApplyTests.anchor
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: TrainingBlock.self,
            configurations: config
        )
        return ModelContext(container)
    }

    // MARK: - endEarly

    func testEndEarlyOnSameDayKeepsBlockAtOneWeek() {
        // User starts a block today and immediately wants to end it.
        // The defensive floor: 1 week minimum so the engine's
        // contains() check still works.
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        TrainingBlockApply.endEarly(block, on: day(0))
        XCTAssertEqual(block.weekCount, 1,
                       "Same-day end shouldn't produce a 0-week block")
    }

    func testEndEarlyMidBlockTruncatesToCoverElapsedDays() {
        // 4-week block, end-early on day 10. Day 10 spans into week 2
        // (days 7-13), so the block should truncate to 2 weeks. After
        // truncation: contains day 10 yes, contains day 14 no.
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        TrainingBlockApply.endEarly(block, on: day(10))
        XCTAssertEqual(block.weekCount, 2,
                       "Day 10 sits in week 2 — truncate to 2 weeks")
        XCTAssertTrue(block.contains(day(10)),
                      "Today should still be inside the (now-truncated) block")
        XCTAssertFalse(block.contains(day(14)),
                       "Day 14 is the start of week 3 — outside the truncated block")
    }

    func testEndEarlyIsIdempotent() {
        // Same call twice produces the same end state — protects
        // against accidental double taps on the action button.
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        TrainingBlockApply.endEarly(block, on: day(10))
        let firstWeekCount = block.weekCount
        TrainingBlockApply.endEarly(block, on: day(10))
        XCTAssertEqual(block.weekCount, firstWeekCount,
                       "Second call mustn't keep shrinking")
    }

    func testEndEarlyOnLastDayLeavesWeekCountUnchanged() {
        // Day 27 is the last day of a 4-week block (days 0-27, end
        // exclusive at day 28). Calling end-early on that day should
        // leave the weekCount at 4 — the block already ends today.
        let block = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        TrainingBlockApply.endEarly(block, on: day(27))
        XCTAssertEqual(block.weekCount, 4,
                       "Already-on-last-day end is a no-op for weekCount")
    }

    // MARK: - startNext

    func testStartNextFromEmptyInsertsAccumulate() throws {
        let context = try makeContext()
        let inserted = TrainingBlockApply.startNext(
            from: [],
            on: day(0),
            in: context
        )
        XCTAssertEqual(inserted.phase, .accumulate)
        XCTAssertEqual(inserted.weekCount, 4)
        XCTAssertEqual(inserted.startDate, cal.startOfDay(for: day(0)))
        // Confirm the row landed in the context.
        let fetched = try context.fetch(FetchDescriptor<TrainingBlock>())
        XCTAssertEqual(fetched.count, 1)
    }

    func testStartNextAfterAccumulateInsertsDeload() throws {
        let context = try makeContext()
        let prior = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        context.insert(prior)

        let inserted = TrainingBlockApply.startNext(
            from: [prior],
            on: day(28),   // day after the accumulate ends
            in: context
        )
        XCTAssertEqual(inserted.phase, .deload,
                       "Engine alternation: after accumulate comes deload")
        XCTAssertEqual(inserted.weekCount, 1)
    }

    func testStartNextAfterDeloadInsertsAccumulate() throws {
        let context = try makeContext()
        let acc = TrainingBlock(startDate: day(0), weekCount: 4, phase: .accumulate)
        let del = TrainingBlock(startDate: day(28), weekCount: 1, phase: .deload)
        context.insert(acc); context.insert(del)

        let inserted = TrainingBlockApply.startNext(
            from: [acc, del],
            on: day(40),
            in: context
        )
        XCTAssertEqual(inserted.phase, .accumulate)
        XCTAssertEqual(inserted.weekCount, 4)
    }

    // MARK: - Past-block ordering smoke test
    //
    // TrainingBlockDetailView sorts `pastBlocks` by startDate descending.
    // This isn't a method on the view (closures inside view bodies are
    // hard to reach), but the underlying ordering contract is — once
    // a block ends, it should be visible in the history list ordered
    // newest-first.

    func testHistoryOrderingNewestFirst() {
        let b1 = TrainingBlock(startDate: day(0),  weekCount: 4, phase: .accumulate)
        let b2 = TrainingBlock(startDate: day(28), weekCount: 1, phase: .deload)
        let b3 = TrainingBlock(startDate: day(35), weekCount: 4, phase: .accumulate)
        let unordered = [b1, b3, b2]
        let sorted = unordered.sorted { $0.startDate > $1.startDate }
        XCTAssertEqual(sorted.map(\.startDate), [b3.startDate, b2.startDate, b1.startDate])
    }
}
