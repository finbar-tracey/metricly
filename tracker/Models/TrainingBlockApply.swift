import Foundation
import SwiftData

/// Mutations on `TrainingBlock` rows that the detail view needs.
/// Lives separately from `TrainingBlockEngine` (pure resolution +
/// recommendation) and `TrainingBlock` itself (model + computed
/// accessors) so the read/write boundary stays clear — same split
/// as `TodayPlanApply` vs `TodayPlanEngine`.
///
/// Each helper is a static function rather than a method on the
/// model so callers (especially UI) can reason about the change in
/// isolation, and so tests can assert the new field values without
/// needing a SwiftData context.
enum TrainingBlockApply {

    // MARK: - End early

    /// Truncate `block` so it ends *today* (exclusive). This is the
    /// "end block early" action from `TrainingBlockDetailView`: the
    /// user finished their accumulate ahead of schedule, or wants
    /// to drop straight into a deload after a hard week.
    ///
    /// Implementation: recompute `weekCount` so the block's exclusive
    /// end date is `startOfDay(now) + 1 day`. Floored at 1 week so
    /// a block ended on the day it started still spans one week —
    /// the engine's `contains(_:)` relies on a non-degenerate
    /// interval, and a 0-week block would break "Week N of M".
    ///
    /// **Idempotent.** Calling twice on the same block does the same
    /// thing the second time as the first — useful guard against
    /// double-tap on the button.
    static func endEarly(_ block: TrainingBlock, on now: Date = .now) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let daysFromStart = cal.dateComponents([.day], from: block.startDate, to: today).day ?? 0
        // Inclusive of today: a block started Mon ending Mon spans 1 day.
        let daysSpanned = max(1, daysFromStart + 1)
        // Round UP to whole weeks so the exclusive endDate lands at a
        // week boundary. 1-7 days = 1 week, 8-14 = 2 weeks, etc.
        let weeks = Int(ceil(Double(daysSpanned) / 7.0))
        block.weekCount = max(1, weeks)
    }

    // MARK: - Start next

    /// Insert the engine-recommended next block into `context`.
    /// Returns the new block so callers can stamp notes or update UI
    /// state immediately without a separate fetch.
    ///
    /// Doesn't save the context — callers usually batch a save after
    /// a couple of related edits. Mirrors the pattern in
    /// `TodayPlanApply.apply`.
    @discardableResult
    static func startNext(
        from blocks: [TrainingBlock],
        on now: Date = .now,
        in context: ModelContext
    ) -> TrainingBlock {
        let rec = TrainingBlockEngine.recommend(from: blocks, at: now)
        let block = TrainingBlock(
            startDate: now,
            weekCount: rec.nextWeekCount,
            phase: rec.nextPhase
        )
        context.insert(block)
        return block
    }
}
