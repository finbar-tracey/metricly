import Foundation

// MARK: - Output

struct TodayPlan: Codable, Equatable {

    enum Intensity: String, Codable {
        case rest, light, moderate, hard

        var label: String {
            switch self {
            case .rest:     return "Rest"
            case .light:    return "Light"
            case .moderate: return "Moderate"
            case .hard:     return "Hard"
            }
        }
    }

    enum Confidence: String, Codable {
        case low, medium, high

        var label: String {
            switch self {
            case .low:    return "Low confidence"
            case .medium: return "Medium confidence"
            case .high:   return "High confidence"
            }
        }
    }

    /// The user's scheduled workout name for today (from settings.weeklyPlan), if any.
    let scheduledName: String?
    /// What we actually recommend — usually the scheduled name; "Rest day" or a
    /// suggested workout type if recovery is poor or nothing is scheduled.
    let recommendedName: String
    let intensity: Intensity
    /// Plain-English reasons behind the recommendation (top 3, ordered by importance).
    let reasons: [String]
    /// Concrete adjustments to apply to the planned session (e.g. "Reduce volume by ~1 set").
    let adjustments: [String]
    let confidence: Confidence
    /// True when the user has already finished a workout today.
    let alreadyTrainedToday: Bool
    /// Muscle groups to train cautiously today (still partially fatigued).
    /// Used by per-exercise hints inside the live workout.
    let goEasyOnGroups: [MuscleGroup]
    /// Muscle groups the user has trained too frequently this week — consider skipping.
    let avoidGroups: [MuscleGroup]

    /// When the plan was last computed. Used to skip stale plans on a new day.
    let generatedAt: Date

    /// Empty placeholder for use as `@State` initial value.
    static let empty = TodayPlan(
        scheduledName: nil,
        recommendedName: "—",
        intensity: .moderate,
        reasons: [],
        adjustments: [],
        confidence: .low,
        alreadyTrainedToday: false,
        goEasyOnGroups: [],
        avoidGroups: [],
        generatedAt: .distantPast
    )
}

// MARK: - Engine

enum TodayPlanEngine {

    /// Generate a plan for today.
    /// - Parameters:
    ///   - scheduledName: Today's planned workout name, if any (empty/nil = no plan).
    ///   - recovery: Output of `RecoveryEngine.evaluate`.
    ///   - health: The same health signals fed into `RecoveryEngine`.
    ///   - recentWorkouts: Finished, non-template workouts from the last ~14 days.
    ///                     Used for muscle-group balance heuristics.
    ///   - alreadyTrainedToday: True if at least one workout/cardio session has finished today.
    ///   - complianceEvents: Recent `PlanComplianceEvent` rows. When the user
    ///                       reliably ignores certain suggestions, the engine
    ///                       lowers its confidence and surfaces a gentle note.
    static func generate(
        scheduledName: String?,
        recovery: RecoveryResult,
        health: HealthSignals,
        recentWorkouts: [Workout] = [],
        alreadyTrainedToday: Bool,
        /// True when the user has at least one finished workout ever (not just
        /// in the recent window). Used to decide whether to show a friendly
        /// "first workout" plan instead of robotic empty-state output.
        hasAnyHistory: Bool = true,
        complianceEvents: [PlanComplianceEvent] = [],
        /// Injectable "now" for testability. Production callers should omit.
        now: Date = .now
    ) -> TodayPlan {

        let cleanScheduled = scheduledName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduled = (cleanScheduled?.isEmpty == false) ? cleanScheduled : nil
        let score = recovery.readinessScore

        // Confidence starts from data-availability (health + workout
        // history). Then we downgrade it if recent compliance has been
        // poor — even a fully-instrumented user can't be predicted with
        // "high confidence" if they reliably ignore the recommendation.
        let baseConfidence = computeConfidence(health, workoutCount: recentWorkouts.count)
        let confidenceSummary = recentCompliance(events: complianceEvents, now: now)
        let confidence: TodayPlan.Confidence = {
            guard let summary = confidenceSummary,
                  summary.rate < EngineConstants.TodayPlan.complianceConfidenceFloor
            else { return baseConfidence }
            // Downgrade by one bucket — high→medium, medium→low.
            switch baseConfidence {
            case .high:   return .medium
            case .medium: return .low
            case .low:    return .low
            }
        }()

        // Already trained — short-circuit, no adjustments needed.
        if alreadyTrainedToday {
            return TodayPlan(
                scheduledName: scheduled,
                recommendedName: scheduled ?? String(localized: "Workout complete", comment: "Plan name shown when the user has already finished training today"),
                intensity: .moderate,
                reasons: [String(localized: "You've already trained today — nice work.", comment: "Reason shown when alreadyTrainedToday is true")],
                adjustments: [],
                confidence: confidence,
                alreadyTrainedToday: true,
                goEasyOnGroups: [],
                avoidGroups: [],
                generatedAt: now
            )
        }

        // First-workout / no-history short-circuit. Brand-new users (no
        // workouts logged ever) would otherwise see "Anything · Moderate ·
        // low confidence", which feels robotic. Welcome them in instead.
        if !hasAnyHistory {
            let firstReason: String = scheduled == nil
                ? String(localized: "Log your first workout to start getting personal recommendations.", comment: "First-time user reason when no schedule")
                : String(localized: "Once you've logged a few sessions, today's plan will adapt to your recovery.", comment: "First-time user reason when a schedule exists")
            return TodayPlan(
                scheduledName: scheduled,
                recommendedName: scheduled ?? String(localized: "Your first workout", comment: "Recommended plan name for brand-new users"),
                intensity: .moderate,
                reasons: [firstReason],
                adjustments: [],
                confidence: .low,
                alreadyTrainedToday: false,
                goEasyOnGroups: [],
                avoidGroups: [],
                generatedAt: now
            )
        }

        // Build reasons (ordered by importance — most decisive first).
        var reasons: [String] = []
        var adjustments: [String] = []

        let C = EngineConstants.TodayPlan.self

        // Intensity decision driven primarily by readiness score.
        let intensity: TodayPlan.Intensity
        if score < C.restThreshold {
            intensity = .rest
            reasons.append(String(localized: "Recovery is low (\(Int(score * 100))%)", comment: "Low-recovery reason. Argument is a 0-100 percent."))
        } else if score < C.lightThreshold {
            intensity = .light
            reasons.append(String(localized: "Partial recovery — a lighter session today will help you bounce back", comment: "Partial-recovery reason"))
        } else if score >= C.hardThreshold {
            intensity = .hard
            reasons.append(String(localized: "Well recovered (\(Int(score * 100))%) — good day to push", comment: "Well-recovered reason. Argument is a 0-100 percent."))
        } else {
            intensity = .moderate
        }

        // Trust calibration: surface when the user has been ignoring
        // suggestions matching today's bucket. The wording is gentle —
        // the engine isn't scolding, just naming the pattern. Only
        // worth surfacing when we have enough events to trust the rate.
        if let summary = confidenceSummary,
           summary.rate < C.complianceCalloutFloor,
           summary.sampleSize >= C.complianceCalloutMinSamples,
           let ignoredKind = summary.mostIgnoredKind,
           intensity == ignoredKind {
            reasons.append(complianceReasonCopy(for: ignoredKind, ignored: summary.ignoredCount(for: ignoredKind)))
        }

        // Sleep callout
        if let sleep = health.sleepMinutes, sleep > 0 {
            let hours = sleep / 60
            if hours < C.sleepShortHours {
                reasons.append(String(format: "Sleep was short (%.1fh)", hours))
            } else if hours >= C.sleepGoodHours {
                reasons.append(String(format: "Slept well (%.1fh)", hours))
            }
        }

        // HRV vs baseline
        if let hrv = health.todayHRV, let avg = health.averageHRV, avg > 0 {
            let pct = (hrv - avg) / avg
            if pct <= -C.hrvCalloutPct {
                reasons.append("HRV is \(Int(abs(pct) * 100))% below your baseline")
            } else if pct >= C.hrvCalloutPct {
                reasons.append("HRV is up \(Int(pct * 100))% from baseline")
            }
        }

        // Resting HR vs baseline
        if let rhr = health.todayRestingHR, let avg = health.averageRestingHR, avg > 0 {
            if rhr > avg + C.rhrCalloutDeltaBpm {
                reasons.append(String(localized: "Resting HR is elevated", comment: "Reason shown when RHR exceeds baseline by the callout threshold"))
            }
        }

        // Fatigued-muscle callout
        let fatigued = recovery.muscleResults.filter { $0.freshness < C.fatiguedFreshnessThreshold }
        let goEasyOnGroups = fatigued.map(\.group)
        if !fatigued.isEmpty && intensity != .rest {
            let names = fatigued.prefix(2).map { $0.group.rawValue }.joined(separator: ", ")
            adjustments.append(String(localized: "Go easy on \(names) — still fatigued", comment: "Adjustment suggestion. Argument is a comma-joined muscle-group name list."))
        }

        // Training balance over the last 7 days — suggest neglected groups
        let neglected = neglectedGroups(in: recentWorkouts, now: now)
        if intensity != .rest, let suggestion = neglected.first {
            // Only mention if the user has been training (not their first week)
            let recentSessionCount = recentWorkouts
                .filter { $0.date >= Calendar.current.date(byAdding: .day, value: -C.neglectedLookbackDays, to: now) ?? .distantPast }
                .count
            if recentSessionCount >= C.neglectedMinRecentSessions {
                let groupName = suggestion.rawValue.lowercased()
                reasons.append(String(localized: "Haven't trained \(groupName) in over a week", comment: "Neglected-group reason. Argument is a lowercased muscle-group name."))
            }
        }

        // Frequency callout: trained the same group multiple times in the last 5 days
        var avoidGroups: [MuscleGroup] = []
        if intensity != .rest, let overworked = overworkedGroup(in: recentWorkouts, now: now) {
            let groupName = overworked.rawValue.lowercased()
            adjustments.append(String(localized: "You've hit \(groupName) several times this week — consider a different focus", comment: "Overworked-group adjustment. Argument is a lowercased muscle-group name."))
            avoidGroups.append(overworked)
        }

        // Intensity-specific adjustments
        switch intensity {
        case .rest:
            adjustments.append(String(localized: "Take a rest day or do gentle movement (walk, mobility)", comment: "Adjustment shown on a rest day"))
        case .light:
            adjustments.append(String(localized: "Reduce volume by ~1 set per exercise", comment: "Adjustment shown on a light day"))
            adjustments.append(String(localized: "Stop 1–2 reps short of failure", comment: "Adjustment shown on a light day"))
        case .hard:
            // Only suggest pushing if confidence is medium+ — otherwise stay conservative
            if confidence != .low {
                adjustments.append(String(localized: "Aim for a top-end set on a key lift", comment: "Adjustment shown on a hard day"))
            }
        case .moderate:
            break
        }

        // Pick recommended workout name
        let recommendedName: String
        if intensity == .rest {
            recommendedName = String(localized: "Rest day", comment: "Recommended-plan name on a rest day")
        } else if let s = scheduled {
            recommendedName = s
        } else {
            recommendedName = recovery.suggestedWorkoutType
        }

        // Trim to top reasons to keep the card scannable
        let topReasons = Array(reasons.prefix(C.maxReasonsShown))

        return TodayPlan(
            scheduledName: scheduled,
            recommendedName: recommendedName,
            intensity: intensity,
            reasons: topReasons,
            adjustments: adjustments,
            confidence: confidence,
            alreadyTrainedToday: false,
            goEasyOnGroups: goEasyOnGroups,
            avoidGroups: avoidGroups,
            generatedAt: now
        )
    }

    // MARK: - Private

    /// Muscle groups the user hasn't trained in the last 7 days, sorted by how
    /// long ago they last worked them (longest first). Excludes Cardio & Other.
    /// Muscle groups the user hasn't *meaningfully* trained in the
    /// lookback window. "Meaningfully" = at least `minWorkingSetsForTrained`
    /// non-warm-up working sets across the period. A group that received
    /// one token set on day 6 still counts as neglected — set-difference
    /// alone misses that.
    private static func neglectedGroups(in workouts: [Workout], now: Date) -> [MuscleGroup] {
        guard !workouts.isEmpty else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: -EngineConstants.TodayPlan.neglectedLookbackDays, to: now) ?? .distantPast
        let minSets = EngineConstants.TodayPlan.neglectedMinWorkingSets

        var setsByGroup: [MuscleGroup: Int] = [:]
        for workout in workouts where workout.date >= cutoff && workout.date <= now {
            for exercise in workout.exercises {
                guard let cat = exercise.category else { continue }
                let workingSets = exercise.sets.filter { !$0.isWarmUp }.count
                if workingSets > 0 {
                    setsByGroup[cat, default: 0] += workingSets
                }
            }
        }

        let candidates: [MuscleGroup] = [.chest, .back, .shoulders, .legs, .biceps, .triceps]
        return candidates.filter { (setsByGroup[$0] ?? 0) < minSets }
    }

    /// A muscle group the user has trained 3+ times in the last 5 days.
    /// Returns the most-trained one, if any.
    /// "Overworked" = a muscle group trained on 3+ distinct days in the
    /// last 5 days. Previously this counted *exercises*, so a single
    /// workout with chest + incline + fly registered as chest hit three
    /// times — the resulting "you've hit chest several times this week"
    /// copy was misleading. Counting distinct days matches the language.
    private static func overworkedGroup(in workouts: [Workout], now: Date) -> MuscleGroup? {
        let C = EngineConstants.TodayPlan.self
        let cutoff = Calendar.current.date(byAdding: .day, value: -C.overworkedLookbackDays, to: now) ?? .distantPast
        let calendar = Calendar.current
        var daysByGroup: [MuscleGroup: Set<Date>] = [:]
        for workout in workouts where workout.date >= cutoff {
            let day = calendar.startOfDay(for: workout.date)
            // Dedupe groups within one workout so chest + incline + fly
            // on the same day counts as one chest day, not three.
            let groups = Set(workout.exercises.compactMap(\.category))
            for group in groups where group != .cardio && group != .other {
                daysByGroup[group, default: []].insert(day)
            }
        }
        return daysByGroup.first { $0.value.count >= C.overworkedDayThreshold }?.key
    }

    /// Confidence has two axes:
    /// - **Health signals** (HRV, resting HR, sleep) — drive the recovery
    ///   model that the recommendation rides on.
    /// - **Workout history depth** — drives whether the engine has seen
    ///   enough of the user's training to make personalised calls.
    ///
    /// A user with perfect HealthKit data but zero logged workouts should
    /// NOT get "high confidence" strength recommendations — the engine
    /// has no idea what their normal looks like yet.
    ///
    /// Mapping (3 final buckets so the UI doesn't need new cases):
    /// - `.low`    — no health AND no workouts
    /// - `.high`   — 2+ health signals AND 7+ recent workouts
    /// - `.medium` — everything in between
    private static func computeConfidence(
        _ health: HealthSignals,
        workoutCount: Int
    ) -> TodayPlan.Confidence {
        var healthCount = 0
        if health.todayHRV != nil { healthCount += 1 }
        if health.todayRestingHR != nil { healthCount += 1 }
        if let s = health.sleepMinutes, s > 0 { healthCount += 1 }

        // Nothing on either axis → low.
        if healthCount == 0 && workoutCount == 0 { return .low }

        // Both axes well-populated → high.
        // ~1 week of training, enough for the recovery engine to see
        // real per-muscle decay patterns.
        if healthCount >= EngineConstants.TodayPlan.confidenceHealthSignalsForHigh
            && workoutCount >= EngineConstants.TodayPlan.confidenceWorkoutsForHigh {
            return .high
        }

        return .medium
    }

    // MARK: - Trust calibration

    /// Summary of how the user has been responding to recent suggestions.
    /// Surfaces in two places:
    /// 1. `confidence` downgrades when overall compliance is below the
    ///    floor (the engine knows it can't predict the user reliably).
    /// 2. A targeted reason fires when the intensity being recommended
    ///    today is the same kind the user habitually ignores.
    struct ComplianceSummary {
        let rate: Double            // 0–1 over the lookback window
        let sampleSize: Int
        let ignoredByKind: [TodayPlan.Intensity: Int]

        /// The intensity bucket the user ignores most (if any tied for top).
        var mostIgnoredKind: TodayPlan.Intensity? {
            ignoredByKind.max(by: { $0.value < $1.value })?.key
        }

        func ignoredCount(for kind: TodayPlan.Intensity) -> Int {
            ignoredByKind[kind] ?? 0
        }
    }

    /// Compute the summary from raw events, dropping ones outside the
    /// lookback window and ones with no suggestion to compare against.
    static func recentCompliance(
        events: [PlanComplianceEvent],
        now: Date = .now
    ) -> ComplianceSummary? {
        let cutoff = Calendar.current.date(
            byAdding: .day,
            value: -EngineConstants.TodayPlan.complianceLookbackDays,
            to: now
        ) ?? .distantPast

        let scored = events.filter { event in
            event.day >= cutoff && event.suggested != nil
        }
        guard !scored.isEmpty else { return nil }

        let complied = scored.filter { $0.complied }.count
        let rate = Double(complied) / Double(scored.count)

        // Bucket non-compliance by the kind of suggestion the user ignored
        // (we care which TYPE of plan they reliably push past).
        var ignored: [TodayPlan.Intensity: Int] = [:]
        for event in scored where !event.complied {
            guard let s = event.suggested else { continue }
            ignored[s, default: 0] += 1
        }

        return ComplianceSummary(rate: rate, sampleSize: scored.count, ignoredByKind: ignored)
    }

    /// Per-intensity-bucket copy for the trust-cal reason line. Stays
    /// tentative on purpose — the engine names the pattern without
    /// scolding.
    static func complianceReasonCopy(for kind: TodayPlan.Intensity, ignored: Int) -> String {
        switch kind {
        case .rest:
            return String(localized: "You've trained through \(ignored) suggested rest days recently — your body may be asking for a real break.", comment: "Trust-cal reason for rest. Argument is a count of ignored rest suggestions.")
        case .light:
            return String(localized: "Recent light-day suggestions got pushed harder — try respecting it this time.", comment: "Trust-cal reason for light intensity")
        case .moderate:
            return String(localized: "Moderate days have been drifting heavy lately — keep a lid on volume today.", comment: "Trust-cal reason for moderate intensity")
        case .hard:
            return String(localized: "Recent hard days have been undertrained — there's room to push if you're up for it.", comment: "Trust-cal reason for hard intensity")
        }
    }

}
