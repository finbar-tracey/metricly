import SwiftUI

/// Everything `TodayPlanDetailView` renders, derived once from the Home
/// snapshot rather than recomputed inside the view body. Mirrors `HomeTodayData`
/// — the design's "scenario" is presentation state over `TodayPlan` +
/// `RecoveryEngine`, not a new engine.
struct PlanDetailData {

    struct MuscleLoad: Identifiable {
        let id = UUID()
        let name: String
        /// 0–100, higher = more used this week (the inverse of freshness).
        let load: Int
        let tone: Color
    }

    struct Lift: Identifiable {
        let id = UUID()
        let name: String
        /// Suggested working weight, formatted in the user's unit, or "—".
        let load: String
        /// Set/rep label, e.g. "4 × 5".
        let sets: String
        let hint: NextUpCard.Exercise.Hint?
    }

    var pillText: String
    var pillAccessibilityLabel: String
    var meta: String
    var titleMain: String
    var titleSuffix: String?
    var reasons: [String]
    var flag: String?
    var muscleLoad: [MuscleLoad]
    var muscleLoadCallout: String?
    var lifts: [Lift]
    var ctaTitle: String
    var ctaSubline: String

    // MARK: - Build

    static func build(
        snapshot: HomeDashboardSnapshot,
        plan: TodayPlan,
        recovery: RecoveryResult,
        weightUnit: WeightUnit,
        progressionSuggestions: [HomeProgressionSuggestion]
    ) -> PlanDetailData {
        let muscle = buildMuscleLoad(recovery: recovery)
        let lifts = buildLifts(
            snapshot: snapshot,
            plan: plan,
            weightUnit: weightUnit,
            progressionSuggestions: progressionSuggestions
        )

        return PlanDetailData(
            pillText: pillText(for: plan),
            pillAccessibilityLabel: plan.intensity == .rest
                ? "Planned rest day"
                : "\(plan.intensity.label) intensity, \(plan.confidence.label)",
            meta: meta(for: plan, lifts: lifts),
            titleMain: plan.intensity == .rest ? "Rest day" : plan.recommendedName,
            titleSuffix: nil,
            reasons: reasons(for: plan, recovery: recovery),
            flag: flag(for: plan),
            muscleLoad: muscle.rows,
            muscleLoadCallout: muscle.callout,
            lifts: lifts,
            ctaTitle: plan.intensity == .rest ? "Log recovery" : "Start workout",
            ctaSubline: ctaSubline(for: plan, lifts: lifts)
        )
    }

    // MARK: - Pill / meta

    private static func pillText(for plan: TodayPlan) -> String {
        guard plan.intensity != .rest else { return "REST · PLANNED" }
        let confidence: String
        switch plan.confidence {
        case .low:    confidence = "LO"
        case .medium: confidence = "MED"
        case .high:   confidence = "HI"
        }
        return "\(plan.intensity.label.uppercased()) · \(confidence) CONF"
    }

    private static func meta(for plan: TodayPlan, lifts: [Lift]) -> String {
        guard plan.intensity != .rest else { return "OPTIONAL · PICK ONE" }
        guard !lifts.isEmpty else { return "NO TEMPLATE YET" }
        // ~3 min per working set plus a warm-up, rounded to 5 — a range the card
        // can honour, not a promise it can't.
        let sets = lifts.reduce(0) { $0 + (Int($1.sets.split(separator: "×").first?
            .trimmingCharacters(in: .whitespaces) ?? "") ?? 3) }
        let minutes = max(10, ((8 + sets * 3) / 5) * 5)
        return "\(lifts.count) LIFTS · ~\(minutes) MIN"
    }

    // MARK: - Reasons / flag

    /// The engine's own reasons, falling back to a readiness summary so the card
    /// is never empty. Rest days get the deload framing, never a guilt-trip.
    private static func reasons(for plan: TodayPlan, recovery: RecoveryResult) -> [String] {
        if !plan.reasons.isEmpty { return plan.reasons }
        var built = [RecoveryEngine.readinessLabel(recovery.readinessScore)]
        built.append(contentsOf: plan.adjustments)
        return built
    }

    private static func flag(for plan: TodayPlan) -> String? {
        if let avoided = plan.avoidGroups.first {
            return "\(avoided.rawValue) trained hard this week — eased off in today's plan"
        }
        if let easy = plan.goEasyOnGroups.first {
            return "\(easy.rawValue) still recovering — kept light today"
        }
        return nil
    }

    // MARK: - Muscle load

    private static func buildMuscleLoad(
        recovery: RecoveryResult
    ) -> (rows: [MuscleLoad], callout: String?) {
        // Load is the inverse of freshness — 0 fresh → 100 loaded. Sorted so the
        // most-used muscle reads top-left, which is where the eye lands first.
        let rows = recovery.muscleResults
            .map { result -> MuscleLoad in
                let load = Int(((1 - result.freshness) * 100).rounded())
                return MuscleLoad(name: result.group.rawValue, load: load, tone: tone(forLoad: load))
            }
            .sorted { $0.load > $1.load }

        // Only call out a genuinely peaking muscle — a routine "Legs at 40" isn't
        // news, and a false alarm every day trains the user to ignore the real one.
        let callout = rows.first.flatMap { $0.load >= 65 ? "\($0.name.uppercased()) PEAKING" : nil }
        return (rows, callout)
    }

    private static func tone(forLoad load: Int) -> Color {
        if load >= 65 { return AppTheme.Dark.Signal.strain }
        if load >= 40 { return AppTheme.Dark.Signal.caution }
        return AppTheme.Dark.Signal.recovery
    }

    // MARK: - Lifts

    private static func buildLifts(
        snapshot: HomeDashboardSnapshot,
        plan: TodayPlan,
        weightUnit: WeightUnit,
        progressionSuggestions: [HomeProgressionSuggestion]
    ) -> [Lift] {
        guard plan.intensity != .rest,
              let template = snapshot.templates.first(where: {
                  $0.name.localizedCaseInsensitiveCompare(plan.recommendedName) == .orderedSame
              })
        else { return [] }

        let easeGroups = Set(plan.goEasyOnGroups + plan.avoidGroups)
        // Most recent logged working weight per exercise name, so a lift with
        // history shows a real number instead of the template's placeholder.
        let lastWeightByName = lastLoggedTopSetWeights(in: snapshot.allWorkouts)
        let suggestionByName = Dictionary(
            progressionSuggestions.map { ($0.exerciseName.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        return template.exercises.sorted { $0.order < $1.order }.map { exercise in
            let working = exercise.sets.filter { !$0.isWarmUp }
            let setCount = max(working.count, 1)
            let key = exercise.name.lowercased()

            // Hint + load agree on the same signal: a progression → PR window and
            // the suggested weight; an eased group → go light; otherwise maintain
            // at the last logged weight.
            let hint: NextUpCard.Exercise.Hint?
            let loadKg: Double?
            if case let .increase(suggested)? = suggestionByName[key]?.recommendation.action {
                hint = .init(text: "PR window", tone: .push)
                loadKg = suggested
            } else if let category = exercise.category, easeGroups.contains(category) {
                hint = .init(text: "Go light", tone: .ease)
                loadKg = lastWeightByName[key]
            } else {
                hint = .init(text: "Maintain", tone: .neutral)
                loadKg = lastWeightByName[key]
            }

            return Lift(
                name: exercise.name,
                load: loadKg.map { weightUnit.formatShort($0) } ?? "—",
                sets: "\(setCount) × \(modeReps(of: working))",
                hint: hint
            )
        }
    }

    /// Most recent logged (non-template) top working-set weight for each
    /// exercise name across the user's history.
    private static func lastLoggedTopSetWeights(in workouts: [Workout]) -> [String: Double] {
        var result: [String: Double] = [:]
        for workout in workouts where workout.isFinished {
            for exercise in workout.exercises {
                let key = exercise.name.lowercased()
                guard result[key] == nil else { continue }  // workouts arrive newest-first
                let top = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max()
                if let top, top > 0 { result[key] = top }
            }
        }
        return result
    }

    /// The rep count the template repeats most — "4 × 5" reads better than an
    /// averaged "4 × 5.75".
    private static func modeReps(of sets: [ExerciseSet]) -> Int {
        let reps = sets.map(\.reps).filter { $0 > 0 }
        guard !reps.isEmpty else { return 0 }
        let counts = Dictionary(grouping: reps, by: { $0 }).mapValues(\.count)
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? reps[0]
    }

    // MARK: - CTA subline

    private static func ctaSubline(for plan: TodayPlan, lifts: [Lift]) -> String {
        if plan.intensity == .rest { return "ANYTHING COUNTS · EVEN NOTHING" }
        // Lead with the first PR-window lift if there is one, else the opener.
        if let pr = lifts.first(where: { $0.hint?.tone == .push }) {
            return "\(pr.name.uppercased()) FIRST · PR WINDOW OPEN"
        }
        if plan.intensity == .light {
            return "KEEP IT EASY · LISTEN TO YOUR BODY"
        }
        if let first = lifts.first {
            return "\(first.name.uppercased()) FIRST"
        }
        return "LET'S GO"
    }
}
