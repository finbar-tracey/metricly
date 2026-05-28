import Foundation
import SwiftData

/// One day's snapshot of "did the user follow the engine's suggestion?".
///
/// Recorded once per calendar day by the compliance backfill on app
/// launch. Lets the engine learn that this user tends to ignore rest
/// suggestions / push harder than light days / etc., and feed that
/// back into today's confidence and reasons.
///
/// The whole point: the original engine was honest but blind — it
/// surfaced recommendations without ever observing what the user did
/// next. With this in place, "high confidence" can actually mean
/// "high confidence the user will take action on it".
@Model
final class PlanComplianceEvent {
    var id: UUID = UUID()
    /// The calendar day this event represents (startOfDay).
    var day: Date = Date()
    /// `TodayPlan.Intensity.rawValue` from the plan that was active on
    /// that day. nil-stored as empty string if no plan was cached
    /// (e.g. the user didn't open the app that day).
    var suggestedIntensityRaw: String = ""
    /// What the user actually did, classified into the same buckets
    /// the engine uses.
    var actualIntensityRaw: String = ""
    /// True when suggested matches actual closely enough (see
    /// `Intensity.matches`). Pre-computed for cheap querying.
    var complied: Bool = false

    init(
        id: UUID = UUID(),
        day: Date,
        suggested: TodayPlan.Intensity?,
        actual: TodayPlan.Intensity,
        complied: Bool
    ) {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.suggestedIntensityRaw = suggested?.rawValue ?? ""
        self.actualIntensityRaw = actual.rawValue
        self.complied = complied
    }

    var suggested: TodayPlan.Intensity? {
        TodayPlan.Intensity(rawValue: suggestedIntensityRaw)
    }

    var actual: TodayPlan.Intensity {
        TodayPlan.Intensity(rawValue: actualIntensityRaw) ?? .moderate
    }
}

// MARK: - Compliance classifier

extension TodayPlan.Intensity {
    /// Compliance match used by the trust-calibration backfill.
    ///
    /// The ONLY soft match is `.light ↔ .moderate`: a user who did a
    /// moderate session on a light day (or vice-versa) is "close enough"
    /// — we don't want to scold them and we don't want trust-cal to
    /// downgrade their confidence.
    ///
    /// `.moderate ↔ .hard` is deliberately NOT a soft match. A user who
    /// always pushes "moderate" days to "hard" is overshooting the
    /// engine's recommendation, and that's a signal trust-cal needs to
    /// see — otherwise the engine can never learn "this user ignores
    /// moderate suggestions and overtrains".
    ///
    /// `.rest` against anything except itself is a hard mismatch — that
    /// covers both "trained hard on a rest day" and "took a rest day
    /// when the engine said train".
    func matches(_ other: TodayPlan.Intensity) -> Bool {
        if self == other { return true }
        switch (self, other) {
        case (.light, .moderate), (.moderate, .light):
            return true
        default:
            return false
        }
    }
}
