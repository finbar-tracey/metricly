import Foundation
import SwiftData

/// One workout's worth of "how did that feel?" feedback, captured at
/// finish time on `FinishWorkoutSheet`.
///
/// Sits alongside `PlanComplianceEvent` in the trust-calibration data
/// layer. The difference: compliance is *inferred* (engine compared
/// what it suggested against what the user actually did),
/// `WorkoutFeedbackEvent` is *reported* (the user told us directly).
/// Reported feedback is higher-quality signal — a workout the engine
/// classified as "moderate" compliance might still have felt grueling
/// to the user, and that's a real input we couldn't otherwise see.
///
/// Optional capture: the picker on `FinishWorkoutSheet` defaults to
/// `.none` and the user can finish without selecting a feel. Only
/// non-nil selections produce a row here — silence isn't a signal.
///
/// One event per day (start-of-day key) — last write wins if the
/// user opens and re-finishes the same workout. The engine reads a
/// rolling 7-day window matching `EngineConstants.TodayPlan.complianceLookbackDays`.
@Model
final class WorkoutFeedbackEvent {
    var id: UUID = UUID()
    /// `Calendar.current.startOfDay(for: workoutDate)`. Keying by day
    /// matches `PlanComplianceEvent` so a future joined query
    /// (compliance + feedback at the same row) reads cleanly.
    var day: Date = Date()
    /// `Feel.rawValue` — stored as raw string so reordering the enum
    /// or adding cases doesn't corrupt existing rows on CloudKit.
    var feelRaw: String = ""
    /// `TodayPlan.Intensity.rawValue` the engine recommended for that
    /// day. Stored at capture time so a later schedule retune doesn't
    /// retroactively change what we said. Empty string when no plan
    /// was cached at capture time (rare — the user finished a workout
    /// before opening Home that day).
    var suggestedIntensityRaw: String = ""

    init(
        id: UUID = UUID(),
        day: Date,
        feel: Feel,
        suggested: TodayPlan.Intensity?
    ) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.feelRaw = feel.rawValue
        self.suggestedIntensityRaw = suggested?.rawValue ?? ""
    }

    /// Reconstruct the enum from raw storage. Returns nil for rows
    /// where the raw value was empty (defensive — shouldn't happen
    /// because the init always sets it).
    var feel: Feel? {
        Feel(rawValue: feelRaw)
    }

    /// The engine's prescription on the day this feedback was given,
    /// reconstructed from raw storage. nil when no plan was cached.
    var suggested: TodayPlan.Intensity? {
        TodayPlan.Intensity(rawValue: suggestedIntensityRaw)
    }
}

extension WorkoutFeedbackEvent {
    /// User-reported difficulty of a workout. Three buckets covers the
    /// signal we need without paralysing the user with options:
    ///   - `.tooEasy`     — could have pushed harder
    ///   - `.aboutRight`  — engine got it right
    ///   - `.tooHard`     — overshot; back off next time
    ///
    /// A future expansion could include `.brutal` and `.cruise` but
    /// the difference is marginal for adaptive-plan tuning and the UI
    /// gets cleaner with three. We can revisit when we have a year of
    /// data to back a wider scale.
    enum Feel: String, CaseIterable, Identifiable {
        case tooEasy    = "too_easy"
        case aboutRight = "about_right"
        case tooHard    = "too_hard"

        var id: String { rawValue }

        /// Compact label used on the picker buttons.
        var label: String {
            switch self {
            case .tooEasy:    return "Too easy"
            case .aboutRight: return "About right"
            case .tooHard:    return "Too hard"
            }
        }

        /// SF Symbol shown on the picker button.
        var icon: String {
            switch self {
            case .tooEasy:    return "arrow.up.right.circle.fill"
            case .aboutRight: return "checkmark.circle.fill"
            case .tooHard:    return "arrow.down.right.circle.fill"
            }
        }
    }
}
