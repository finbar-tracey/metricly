import Foundation

/// Pure-function engine for resolving the active `TrainingBlock` at a
/// given date and recommending when to advance to the next block.
///
/// **Resolution model.** Blocks are contiguous from `startDate` to
/// `startDate + weekCount*7`, exclusive at the upper bound. Gaps
/// between blocks are allowed and produce `nil` (no active
/// periodisation — engine falls back to recovery-driven intensity).
///
/// **Advancement is a recommendation, not a side effect.** The engine
/// returns an `AdvancementRecommendation` describing what the next
/// block *should* look like. Persisting the new block is the
/// caller's call — usually a daily nudge banner on Home that says
/// "Last block finished. Start a deload?" with Yes / No buttons.
/// That keeps the user in control: no surprise deload weeks because
/// some date math said so.
///
/// **Alternation heuristic.** When the current block was an
/// `.accumulate`, the next recommendation is `.deload` for 1 week.
/// When it was a `.deload`, the next is `.accumulate` for 4 weeks.
/// These constants live in `EngineConstants.TrainingBlock` (added
/// alongside this engine) so a future "long deload" experiment can
/// override without rewriting the engine.
enum TrainingBlockEngine {

    // MARK: - Resolution

    /// The block whose window contains `date`, or `nil` if none does.
    /// O(n) over the block list — fine for the realistic block counts
    /// (a year of training is ~13 blocks at 4-on/1-off).
    static func currentBlock(in blocks: [TrainingBlock],
                             at date: Date = .now) -> TrainingBlock? {
        blocks.first { $0.contains(date) }
    }

    /// The most recent block whose `endDate` is on or before `date`.
    /// Used to decide what *kind* of block to recommend next when
    /// there's currently no active one.
    static func mostRecentlyEnded(in blocks: [TrainingBlock],
                                  before date: Date = .now) -> TrainingBlock? {
        blocks
            .filter { $0.endDate <= Calendar.current.startOfDay(for: date) }
            .max(by: { $0.endDate < $1.endDate })
    }

    // MARK: - Advancement

    /// What the next block should look like, given the user's block
    /// history. Returned even when there's no need to act immediately
    /// — the caller decides whether to surface a nudge based on
    /// `shouldRecommendNow`.
    struct AdvancementRecommendation: Equatable {
        /// Suggested phase for the next block.
        let nextPhase: TrainingBlock.Phase
        /// Suggested duration (weeks) for the next block.
        let nextWeekCount: Int
        /// True when the user has no active block and the most-recent
        /// one ended on or before `date`. False when an active block
        /// still has time left — surfacing a nudge in that case would
        /// be premature.
        let shouldRecommendNow: Bool
        /// One-line user-facing rationale ("Accumulation finished —
        /// schedule a deload week.").
        let rationale: String
    }

    /// Recommend what comes next. Two paths:
    ///  - Empty history → start a fresh `.accumulate` (4 weeks).
    ///    Always `shouldRecommendNow = true` — the user explicitly
    ///    opted in by tapping "Start a training block".
    ///  - Has history → alternate based on the most-recent block's
    ///    phase. `shouldRecommendNow = true` only when there's no
    ///    active block on `date`.
    static func recommend(from blocks: [TrainingBlock],
                          at date: Date = .now) -> AdvancementRecommendation {
        let active = currentBlock(in: blocks, at: date)
        let lastEnded = mostRecentlyEnded(in: blocks, before: date)

        // No history at all: bootstrap a default accumulate block.
        guard let last = lastEnded ?? active else {
            return AdvancementRecommendation(
                nextPhase: .accumulate,
                nextWeekCount: 4,
                shouldRecommendNow: true,
                rationale: "Start a 4-week accumulation block."
            )
        }

        // Alternate phases. The "next" block's shape is determined by
        // the most recent block we have, not by the active one — once
        // an active block ends, the recommendation flips.
        let nextPhase: TrainingBlock.Phase
        let nextWeekCount: Int
        let rationale: String
        switch last.phase {
        case .accumulate:
            nextPhase = .deload
            nextWeekCount = 1
            rationale = "Accumulation finished — schedule a deload week."
        case .deload:
            nextPhase = .accumulate
            nextWeekCount = 4
            rationale = "Deload finished — start the next accumulation block."
        }

        return AdvancementRecommendation(
            nextPhase: nextPhase,
            nextWeekCount: nextWeekCount,
            // Only surface a nudge when nothing is currently active.
            // An active block (even the last one we have) means the
            // user is mid-arc — recommending the next one is noise.
            shouldRecommendNow: active == nil,
            rationale: rationale
        )
    }

    // MARK: - Display

    /// "Week 2 of 4" for the Home chip and detail view. Returns nil
    /// when there's no active block.
    static func progressLabel(for block: TrainingBlock,
                              at date: Date = .now) -> String? {
        guard let week = block.weekIndex(at: date) else { return nil }
        return "Week \(week) of \(block.weekCount)"
    }
}
