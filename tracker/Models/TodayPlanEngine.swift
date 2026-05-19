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
    static func generate(
        scheduledName: String?,
        recovery: RecoveryResult,
        health: HealthSignals,
        recentWorkouts: [Workout] = [],
        alreadyTrainedToday: Bool,
        /// True when the user has at least one finished workout ever (not just
        /// in the recent window). Used to decide whether to show a friendly
        /// "first workout" plan instead of robotic empty-state output.
        hasAnyHistory: Bool = true
    ) -> TodayPlan {

        let cleanScheduled = scheduledName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let scheduled = (cleanScheduled?.isEmpty == false) ? cleanScheduled : nil
        let score = recovery.readinessScore

        // Confidence is determined by how many real-time health signals we have.
        let confidence = computeConfidence(health, workoutCount: recentWorkouts.count)

        // Already trained — short-circuit, no adjustments needed.
        if alreadyTrainedToday {
            return TodayPlan(
                scheduledName: scheduled,
                recommendedName: scheduled ?? "Workout complete",
                intensity: .moderate,
                reasons: ["You've already trained today — nice work."],
                adjustments: [],
                confidence: confidence,
                alreadyTrainedToday: true,
                goEasyOnGroups: [],
                avoidGroups: [],
                generatedAt: .now
            )
        }

        // First-workout / no-history short-circuit. Brand-new users (no
        // workouts logged ever) would otherwise see "Anything · Moderate ·
        // low confidence", which feels robotic. Welcome them in instead.
        if !hasAnyHistory {
            return TodayPlan(
                scheduledName: scheduled,
                recommendedName: scheduled ?? "Your first workout",
                intensity: .moderate,
                reasons: scheduled == nil
                    ? ["Log your first workout to start getting personal recommendations."]
                    : ["Once you've logged a few sessions, today's plan will adapt to your recovery."],
                adjustments: [],
                confidence: .low,
                alreadyTrainedToday: false,
                goEasyOnGroups: [],
                avoidGroups: [],
                generatedAt: .now
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
            reasons.append("Recovery is low (\(Int(score * 100))%)")
        } else if score < C.lightThreshold {
            intensity = .light
            reasons.append("Partial recovery — a lighter session today will help you bounce back")
        } else if score >= C.hardThreshold {
            intensity = .hard
            reasons.append("Well recovered (\(Int(score * 100))%) — good day to push")
        } else {
            intensity = .moderate
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
                reasons.append("Resting HR is elevated")
            }
        }

        // Fatigued-muscle callout
        let fatigued = recovery.muscleResults.filter { $0.freshness < C.fatiguedFreshnessThreshold }
        let goEasyOnGroups = fatigued.map(\.group)
        if !fatigued.isEmpty && intensity != .rest {
            let names = fatigued.prefix(2).map { $0.group.rawValue }.joined(separator: ", ")
            adjustments.append("Go easy on \(names) — still fatigued")
        }

        // Training balance over the last 7 days — suggest neglected groups
        let neglected = neglectedGroups(in: recentWorkouts)
        if intensity != .rest, let suggestion = neglected.first {
            // Only mention if the user has been training (not their first week)
            let recentSessionCount = recentWorkouts
                .filter { $0.date >= Calendar.current.date(byAdding: .day, value: -C.neglectedLookbackDays, to: .now) ?? .distantPast }
                .count
            if recentSessionCount >= C.neglectedMinRecentSessions {
                reasons.append("Haven't trained \(suggestion.rawValue.lowercased()) in over a week")
            }
        }

        // Frequency callout: trained the same group multiple times in the last 5 days
        var avoidGroups: [MuscleGroup] = []
        if intensity != .rest, let overworked = overworkedGroup(in: recentWorkouts) {
            adjustments.append("You've hit \(overworked.rawValue.lowercased()) several times this week — consider a different focus")
            avoidGroups.append(overworked)
        }

        // Intensity-specific adjustments
        switch intensity {
        case .rest:
            adjustments.append("Take a rest day or do gentle movement (walk, mobility)")
        case .light:
            adjustments.append("Reduce volume by ~1 set per exercise")
            adjustments.append("Stop 1–2 reps short of failure")
        case .hard:
            // Only suggest pushing if confidence is medium+ — otherwise stay conservative
            if confidence != .low {
                adjustments.append("Aim for a top-end set on a key lift")
            }
        case .moderate:
            break
        }

        // Pick recommended workout name
        let recommendedName: String
        if intensity == .rest {
            recommendedName = "Rest day"
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
            generatedAt: .now
        )
    }

    // MARK: - Private

    /// Muscle groups the user hasn't trained in the last 7 days, sorted by how
    /// long ago they last worked them (longest first). Excludes Cardio & Other.
    private static func neglectedGroups(in workouts: [Workout]) -> [MuscleGroup] {
        guard !workouts.isEmpty else { return [] }
        let cutoff = Calendar.current.date(byAdding: .day, value: -EngineConstants.TodayPlan.neglectedLookbackDays, to: .now) ?? .distantPast
        let recentExercises = workouts
            .filter { $0.date >= cutoff }
            .flatMap(\.exercises)

        var trained = Set<MuscleGroup>()
        for ex in recentExercises {
            if let cat = ex.category { trained.insert(cat) }
        }

        let candidates: [MuscleGroup] = [.chest, .back, .shoulders, .legs, .biceps, .triceps]
        return candidates.filter { !trained.contains($0) }
    }

    /// A muscle group the user has trained 3+ times in the last 5 days.
    /// Returns the most-trained one, if any.
    /// "Overworked" = a muscle group trained on 3+ distinct days in the
    /// last 5 days. Previously this counted *exercises*, so a single
    /// workout with chest + incline + fly registered as chest hit three
    /// times — the resulting "you've hit chest several times this week"
    /// copy was misleading. Counting distinct days matches the language.
    private static func overworkedGroup(in workouts: [Workout]) -> MuscleGroup? {
        let C = EngineConstants.TodayPlan.self
        let cutoff = Calendar.current.date(byAdding: .day, value: -C.overworkedLookbackDays, to: .now) ?? .distantPast
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

}
