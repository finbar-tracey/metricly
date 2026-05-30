import Foundation
import SwiftData

/// A multi-week training block — the periodisation primitive that
/// lets Metricly tell a multi-week narrative ("you're in week 2 of a
/// 4-week accumulation block, deload next week") instead of only
/// day-by-day intensity calls.
///
/// **Why a single block model rather than program-style nesting.**
/// A full periodisation model would have programs → mesocycles →
/// microcycles → days. That works for athletes following a coach's
/// plan; it overshoots Metricly's user who's lifting consistently
/// but not on a written program. One linear sequence of blocks
/// (`Accumulate → Deload → Accumulate → ...`) gives the same
/// narrative scaffolding with a fraction of the schema surface.
///
/// **Blocks are contiguous, not overlapping.** Each block has a
/// `startDate` and a `weekCount`; its end date is computed (start +
/// weekCount * 7). When a block ends, the next one begins
/// immediately. The engine's `currentBlock(at:)` returns whichever
/// block's window contains the queried date — at most one.
///
/// **Phase informs intensity, not recovery.** During a `.deload`
/// block, `TodayPlanEngine` caps intensity at `.light` and rewrites
/// the reason copy. The recovery math itself is untouched — readiness
/// scoring is still driven by sleep / HRV / soreness. The block is
/// a periodisation override on the *prescription*, not a replacement
/// of the underlying signal.
///
/// **One block per day** (start-of-day key on `startDate`). The
/// resolver picks the block whose window contains the queried date;
/// gaps between blocks are allowed and produce a nil result (no
/// active periodisation).
@Model
final class TrainingBlock {
    var id: UUID = UUID()

    /// First day of the block. `Calendar.current.startOfDay`-normalised
    /// so duration math doesn't shift by a fraction of a day on DST
    /// boundaries or daylight transitions.
    var startDate: Date = Date()

    /// How many weeks this block lasts. Constrained to 1...12 at the
    /// constructor; clamping is defensive against future writers.
    var weekCount: Int = 4

    /// `Phase.rawValue` — stored as raw string so reordering or adding
    /// cases doesn't corrupt existing rows on CloudKit.
    var phaseRaw: String = ""

    /// Optional user-facing note ("first 4-week push after holidays",
    /// "post-meet deload"). Not consumed by the engine — only surfaced
    /// in the block detail view. Empty string when not set.
    var notes: String = ""

    init(
        id: UUID = UUID(),
        startDate: Date,
        weekCount: Int,
        phase: Phase,
        notes: String = ""
    ) {
        self.id = id
        self.startDate = Calendar.current.startOfDay(for: startDate)
        // Clamp to a sensible range — a 0- or 100-week block both
        // break the "Week N of M" UI and the engine's auto-advance
        // recommendation.
        self.weekCount = max(1, min(12, weekCount))
        self.phaseRaw = phase.rawValue
        self.notes = notes
    }

    /// Reconstruct the enum from raw storage. Returns `.accumulate`
    /// as a defensive fallback for rows where the raw value didn't
    /// round-trip cleanly — losing periodisation context shouldn't
    /// corrupt the user's view of the block.
    var phase: Phase {
        Phase(rawValue: phaseRaw) ?? .accumulate
    }

    /// Computed end-of-block date — exclusive upper bound. A 4-week
    /// block starting Mon May 4 ends Mon Jun 1 (week 5 is the *next*
    /// block, not this one).
    var endDate: Date {
        Calendar.current.date(byAdding: .day,
                              value: weekCount * 7,
                              to: startDate) ?? startDate
    }

    /// True when `date` falls within `[startDate, endDate)`. The half-
    /// open interval matches how `currentBlock(at:)` resolves which
    /// block owns a given day; the block ending on Monday Jun 1 does
    /// NOT own Jun 1 — the next block does.
    func contains(_ date: Date) -> Bool {
        let day = Calendar.current.startOfDay(for: date)
        return day >= startDate && day < endDate
    }

    /// 1-indexed week within the block at the given date. Returns nil
    /// if the date falls outside the block. Week 1 covers days 0-6,
    /// week 2 covers days 7-13, etc.
    func weekIndex(at date: Date) -> Int? {
        guard contains(date) else { return nil }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        let days = cal.dateComponents([.day], from: startDate, to: day).day ?? 0
        return (days / 7) + 1
    }
}

extension TrainingBlock {

    /// The two block phases Metricly currently models. A future
    /// `.peak` phase (taper before a meet or test week) is possible
    /// but most users aren't on a meet schedule — the accumulate /
    /// deload alternation is enough for general fitness narrative.
    ///
    /// **Accumulate.** The default. Volume and load accumulate
    /// across the block; intensity is driven by the recovery engine
    /// without periodisation override. This is what most weeks
    /// outside a deload look like.
    ///
    /// **Deload.** A planned recovery week. `TodayPlanEngine` caps
    /// intensity at `.light` for the duration, regardless of how
    /// recovered the user is, on the theory that the *point* of a
    /// deload is to let cumulative fatigue dissipate even on days
    /// you feel fine. Usually 1 week, occasionally 2 after a long
    /// accumulate.
    enum Phase: String, CaseIterable, Identifiable {
        case accumulate = "accumulate"
        case deload     = "deload"

        var id: String { rawValue }

        /// Short label for the Home chip and detail view.
        var label: String {
            switch self {
            case .accumulate: return "Accumulation"
            case .deload:     return "Deload"
            }
        }

        /// One-sentence description of what the phase implies — used
        /// on the block detail view as user-facing copy.
        var blurb: String {
            switch self {
            case .accumulate:
                return "Build volume and load while recovery allows."
            case .deload:
                return "Planned recovery week — keep sessions light."
            }
        }

        /// SF Symbol for chip / row decoration.
        var icon: String {
            switch self {
            case .accumulate: return "arrow.up.right"
            case .deload:     return "arrow.down.right"
            }
        }
    }
}
