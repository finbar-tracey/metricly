import SwiftUI

// MARK: - Input / Output Types

struct HealthSignals {
    var todayHRV: Double?
    var averageHRV: Double?
    var todayRestingHR: Double?
    var averageRestingHR: Double?
    var sleepMinutes: Double?

    init(
        todayHRV: Double? = nil,
        averageHRV: Double? = nil,
        todayRestingHR: Double? = nil,
        averageRestingHR: Double? = nil,
        sleepMinutes: Double? = nil
    ) {
        self.todayHRV = todayHRV
        self.averageHRV = averageHRV
        self.todayRestingHR = todayRestingHR
        self.averageRestingHR = averageRestingHR
        self.sleepMinutes = sleepMinutes
    }
}

struct MuscleFatigueResult: Identifiable {
    let id = UUID()
    let group: MuscleGroup
    let freshness: Double              // 0 = fatigued, 1 = recovered
    let lastTrained: Date?
    let effectiveRecoveryHours: Double
}

struct RecoveryResult {
    let readinessScore: Double         // 0...1
    let muscleResults: [MuscleFatigueResult]
    let suggestedWorkoutType: String
}

// MARK: - Internal Types

private struct MuscleSession {
    let date: Date
    let workingSets: Int
    let totalVolume: Double            // sum(reps * weight) for working sets
    let averageRPE: Double?
}

// MARK: - Engine

enum RecoveryEngine {

    static let baseRecoveryHours: [MuscleGroup: Double] = [
        .chest: 48, .back: 48, .shoulders: 48,
        .biceps: 36, .triceps: 36, .legs: 72,
        .core: 24, .cardio: 24, .other: 48
    ]

    static let trainableGroups: [MuscleGroup] = MuscleGroup.allCases
        .filter { $0 != .cardio && $0 != .other }

    // MARK: - Public API

    /// Compute full recovery state.
    /// - Parameters:
    ///   - workouts: Finished, non-template workouts sorted newest-first.
    ///   - health: Optional health signals. Pass default if unavailable.
    ///   - externalWorkouts: HealthKit workouts (non-app).
    ///   - cardioSessions: App-native cardio sessions (runs, rides, walks).
    ///   - now: Injectable for testability.
    static func evaluate(
        workouts: [Workout],
        health: HealthSignals = .init(),
        externalWorkouts: [ExternalWorkout] = [],
        cardioSessions: [CardioSession] = [],
        now: Date = .now
    ) -> RecoveryResult {
        let healthMultiplier = computeHealthMultiplier(health: health)

        var muscleResults: [MuscleFatigueResult] = trainableGroups.map { group in
            computeMuscleFatigue(
                for: group,
                workouts: workouts,
                health: health,
                healthMultiplier: healthMultiplier,
                now: now
            )
        }

        // Apply systemic fatigue from external workouts (runs, rides, etc.)
        muscleResults = applyExternalWorkoutFatigue(
            muscleResults: muscleResults,
            externalWorkouts: externalWorkouts,
            now: now
        )

        // Apply systemic fatigue from app-native cardio sessions
        muscleResults = applyCardioSessionFatigue(
            muscleResults: muscleResults,
            cardioSessions: cardioSessions,
            now: now
        )

        let readinessScore = computeReadinessScore(
            muscleResults: muscleResults,
            health: health
        )

        let suggestedType = suggestWorkoutType(from: muscleResults)

        return RecoveryResult(
            readinessScore: readinessScore,
            muscleResults: muscleResults.sorted { $0.freshness > $1.freshness },
            suggestedWorkoutType: suggestedType
        )
    }

    // MARK: - Per-Muscle Fatigue

    private static func computeMuscleFatigue(
        for group: MuscleGroup,
        workouts: [Workout],
        health: HealthSignals,
        healthMultiplier: Double,
        now: Date
    ) -> MuscleFatigueResult {
        let base = baseRecoveryHours[group] ?? 48
        let lookbackHours = base * 2

        // Gather all sessions for this muscle within the lookback window
        let sessions = recentSessions(
            for: group,
            from: workouts,
            now: now,
            lookbackHours: lookbackHours
        )

        guard !sessions.isEmpty else {
            return MuscleFatigueResult(
                group: group,
                freshness: 1.0,
                lastTrained: nil,
                effectiveRecoveryHours: base * healthMultiplier
            )
        }

        // Trailing 28-day average volume for this muscle group
        let trailingAvgVolume = trailingAverageVolume(
            for: group,
            from: workouts,
            before: now,
            days: 28
        )

        // Compound freshness across all sessions in the window
        var compositeFreshness = 1.0
        var latestEffectiveRecovery = base * healthMultiplier

        for session in sessions {
            // Volume multiplier
            let volumeMultiplier: Double
            if let avg = trailingAvgVolume, avg > 0, session.totalVolume > 0 {
                let volumeRatio = session.totalVolume / avg
                volumeMultiplier = 0.7 + 0.6 * min(volumeRatio, 2.0)
            } else {
                volumeMultiplier = 1.0
            }

            // RPE multiplier
            let rpeMultiplier: Double
            if let avgRPE = session.averageRPE {
                rpeMultiplier = 0.55 + 0.075 * avgRPE
            } else {
                rpeMultiplier = 1.0
            }

            let effectiveRecovery = base * volumeMultiplier * rpeMultiplier * healthMultiplier
            let hoursSince = now.timeIntervalSince(session.date) / 3600
            let sessionFreshness = min(1.0, max(0.0, hoursSince / effectiveRecovery))

            // Compound fatigue: each session's residual reduces composite
            let residualFatigue = 1.0 - sessionFreshness
            compositeFreshness *= (1.0 - residualFatigue * 0.6)

            // Track the most recent session's effective recovery for display
            if session.date == sessions.first?.date {
                latestEffectiveRecovery = effectiveRecovery
            }
        }

        return MuscleFatigueResult(
            group: group,
            freshness: min(1.0, max(0.0, compositeFreshness)),
            lastTrained: sessions.first?.date,
            effectiveRecoveryHours: latestEffectiveRecovery
        )
    }

    // MARK: - Session Extraction

    private static func recentSessions(
        for group: MuscleGroup,
        from workouts: [Workout],
        now: Date,
        lookbackHours: Double
    ) -> [MuscleSession] {
        let cutoff = now.addingTimeInterval(-lookbackHours * 3600)
        var sessions: [MuscleSession] = []

        for workout in workouts {
            guard workout.date >= cutoff else { break } // sorted newest-first
            guard workout.endTime != nil else { continue } // only finished workouts

            let matchingExercises = workout.exercises.filter { $0.category == group }
            guard !matchingExercises.isEmpty else { continue }

            var totalSets = 0
            var totalVolume = 0.0
            var rpeSum = 0.0
            var rpeCount = 0

            for exercise in matchingExercises {
                let workingSets = exercise.sets.filter { !$0.isWarmUp }
                totalSets += workingSets.count
                for set in workingSets {
                    totalVolume += Double(set.reps) * set.weight
                    if let rpe = set.rpe, rpe > 0 {
                        rpeSum += Double(rpe)
                        rpeCount += 1
                    }
                }
            }

            guard totalSets > 0 else { continue }

            sessions.append(MuscleSession(
                date: workout.date,
                workingSets: totalSets,
                totalVolume: totalVolume,
                averageRPE: rpeCount > 0 ? rpeSum / Double(rpeCount) : nil
            ))
        }

        return sessions // already newest-first from input order
    }

    // MARK: - Trailing Average Volume

    private static func trailingAverageVolume(
        for group: MuscleGroup,
        from workouts: [Workout],
        before now: Date,
        days: Int
    ) -> Double? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: now) ?? now

        var sessionVolumes: [Double] = []
        for workout in workouts {
            guard workout.date >= cutoff, workout.endTime != nil else {
                if workout.date < cutoff { break }
                continue
            }

            let matchingExercises = workout.exercises.filter { $0.category == group }
            guard !matchingExercises.isEmpty else { continue }

            var volume = 0.0
            for exercise in matchingExercises {
                for set in exercise.sets where !set.isWarmUp {
                    volume += Double(set.reps) * set.weight
                }
            }
            if volume > 0 {
                sessionVolumes.append(volume)
            }
        }

        guard sessionVolumes.count >= 2 else { return nil }
        return sessionVolumes.reduce(0, +) / Double(sessionVolumes.count)
    }

    // MARK: - Health Multiplier

    /// Computes a multiplier that adjusts base recovery hours based on health signals.
    /// > 1.0 means slower recovery (more fatigued), < 1.0 means faster recovery.
    private static func computeHealthMultiplier(health: HealthSignals) -> Double {
        var multiplier = 1.0

        // HRV signal
        if let hrv = health.todayHRV, let avg = health.averageHRV, avg > 0 {
            let ratio = hrv / avg
            if ratio < 0.85 {
                multiplier *= 1.20   // suppressed HRV = slower recovery
            } else if ratio > 1.15 {
                multiplier *= 0.85   // elevated HRV = faster recovery
            }
        }

        // Sleep signal
        if let sleepMins = health.sleepMinutes, sleepMins > 0 {
            let sleepHours = sleepMins / 60
            if sleepHours < 6 {
                multiplier *= 1.15   // poor sleep = slower recovery
            }
        }

        // Resting HR signal
        if let rhr = health.todayRestingHR, let avg = health.averageRestingHR, avg > 0 {
            let rhrRatio = rhr / avg
            if rhrRatio > 1.10 {
                multiplier *= 1.15   // significantly elevated RHR
            } else if rhrRatio > 1.05 {
                multiplier *= 1.07   // mildly elevated RHR
            }
        }

        return multiplier
    }

    // MARK: - Aggregate Readiness Score

    private static func computeReadinessScore(
        muscleResults: [MuscleFatigueResult],
        health: HealthSignals
    ) -> Double {
        guard !muscleResults.isEmpty else { return 0.5 }

        var score = muscleResults.map(\.freshness).reduce(0, +) / Double(muscleResults.count)

        // HRV modifier on aggregate (±20%)
        if let hrv = health.todayHRV, let avg = health.averageHRV, avg > 0 {
            let hrvModifier = ((hrv / avg) - 1.0) * 0.2
            score = min(1.0, max(0.0, score + hrvModifier))
        }

        // Resting HR modifier on aggregate
        if let rhr = health.todayRestingHR, let avg = health.averageRestingHR, avg > 0 {
            let rhrRatio = rhr / avg
            if rhrRatio > 1.10 {
                score *= 0.90
            } else if rhrRatio > 1.05 {
                score *= 0.95
            }
        }

        // Sleep modifier on aggregate
        if let sleepMins = health.sleepMinutes, sleepMins > 0 {
            let sleepHours = sleepMins / 60
            if sleepHours < 6 {
                score *= 0.80
            } else if sleepHours >= 7.5 {
                score = min(1.0, score * 1.10)
            }
        }

        return min(1.0, max(0.0, score))
    }

    // MARK: - External Workout Fatigue

    private static func applyExternalWorkoutFatigue(
        muscleResults: [MuscleFatigueResult],
        externalWorkouts: [ExternalWorkout],
        now: Date
    ) -> [MuscleFatigueResult] {
        let external = externalWorkouts.filter { !$0.isFromThisApp }
        guard !external.isEmpty else { return muscleResults }

        // Only consider workouts from the last 48 hours
        let cutoff = now.addingTimeInterval(-48 * 3600)
        let recentExternal = external.filter { $0.endDate >= cutoff }
        guard !recentExternal.isEmpty else { return muscleResults }

        // Sum fatigue weighted by recency
        var totalExternalFatigue = 0.0
        for workout in recentExternal {
            let hoursSince = now.timeIntervalSince(workout.endDate) / 3600
            let recencyFactor = max(0, 1.0 - hoursSince / 48.0)
            totalExternalFatigue += workout.estimatedFatigueScore * recencyFactor
        }

        // Cap impact at 30% freshness reduction
        let fatigueImpact = min(0.3, totalExternalFatigue * 0.15)

        return muscleResults.map { result in
            MuscleFatigueResult(
                group: result.group,
                freshness: max(0, result.freshness - fatigueImpact),
                lastTrained: result.lastTrained,
                effectiveRecoveryHours: result.effectiveRecoveryHours
            )
        }
    }

    // MARK: - Cardio Session Fatigue

    /// Applies fatigue from the user's own cardio sessions (runs, rides, walks).
    /// Cardio is systemic — it hits every muscle group, but legs/lower body hardest.
    /// A 5 km easy run reduces leg freshness ~20-25%; a 20 km long run can reduce it ~55%.
    private static func applyCardioSessionFatigue(
        muscleResults: [MuscleFatigueResult],
        cardioSessions: [CardioSession],
        now: Date
    ) -> [MuscleFatigueResult] {
        // Look back 72 h — a hard long run can linger for 3 days in the legs
        let cutoff = now.addingTimeInterval(-72 * 3600)
        let recent = cardioSessions.filter { $0.date >= cutoff }
        guard !recent.isEmpty else { return muscleResults }

        // Compute a 0–2 fatigue magnitude per session and weight by recency
        var totalLegs   = 0.0   // fatigue magnitude that hits legs heavily
        var totalSystemic = 0.0 // fatigue magnitude for everything else

        for session in recent {
            let hoursSince = now.timeIntervalSince(session.date) / 3600

            // Recency: full weight within 24 h, tapering to 0 at 72 h
            let recencyFactor = max(0.0, 1.0 - hoursSince / 72.0)
            guard recencyFactor > 0 else { continue }

            // Intensity by type
            let typeIntensity: Double
            switch session.type {
            case .outdoorRun, .indoorRun:    typeIntensity = 1.00
            case .outdoorCycle:              typeIntensity = 0.65
            case .outdoorWalk, .indoorWalk:  typeIntensity = 0.25
            }

            // Duration contribution (90 min = full duration score)
            let durationScore = min(1.0, session.durationSeconds / (90 * 60))

            // Distance contribution (20 km = full distance score)
            let distanceScore = min(1.0, session.distanceMeters / 20_000)

            // Pace contribution for runs (faster = more fatigue)
            var paceMultiplier = 1.0
            if (session.type == .outdoorRun || session.type == .indoorRun),
               session.avgPaceSecPerKm > 0 {
                let zone = PaceZone.zone(for: session.avgPaceSecPerKm)
                switch zone {
                case .speed:     paceMultiplier = 1.40
                case .threshold: paceMultiplier = 1.25
                case .tempo:     paceMultiplier = 1.12
                case .aerobic:   paceMultiplier = 1.00
                case .easy:      paceMultiplier = 0.85
                case .recovery:  paceMultiplier = 0.70
                }
            }

            // Combine into a 0–2 magnitude score
            let magnitude = typeIntensity * max(durationScore, distanceScore) * paceMultiplier * 2.0

            totalLegs      += magnitude * recencyFactor
            totalSystemic  += magnitude * recencyFactor * 0.45 // systemic is ~45% of leg impact
        }

        // Convert to freshness reductions, capped so one session can't zero you out
        // Legs: up to 60% reduction for a very hard long run
        let legImpact      = min(0.60, totalLegs      * 0.18)
        // Everything else: up to 30% reduction
        let systemicImpact = min(0.30, totalSystemic  * 0.18)

        return muscleResults.map { result in
            let impact = (result.group == .legs) ? legImpact : systemicImpact
            return MuscleFatigueResult(
                group: result.group,
                freshness: max(0, result.freshness - impact),
                lastTrained: result.lastTrained,
                effectiveRecoveryHours: result.effectiveRecoveryHours
            )
        }
    }

    // MARK: - Suggested Workout Type

    static func suggestWorkoutType(from results: [MuscleFatigueResult]) -> String {
        let ready = Set(results.filter { $0.freshness >= 0.7 }.map(\.group))
        if ready.contains(.chest) && ready.contains(.shoulders) && ready.contains(.triceps) {
            return "Push Day"
        } else if ready.contains(.back) && ready.contains(.biceps) {
            return "Pull Day"
        } else if ready.contains(.legs) {
            return "Leg Day"
        } else if ready.count >= 3 {
            return "Full Body"
        } else {
            return "Recovery"
        }
    }

    // MARK: - Display Helpers

    static func freshnessColor(_ freshness: Double) -> Color {
        if freshness >= 0.8 { return .green }
        if freshness >= 0.5 { return .yellow }
        if freshness >= 0.25 { return .orange }
        return .red
    }

    static func freshnessLabel(_ freshness: Double) -> String {
        if freshness >= 0.8 { return "Ready" }
        if freshness >= 0.5 { return "Almost" }
        if freshness >= 0.25 { return "Recovering" }
        return "Fatigued"
    }

    static func readinessLabel(_ score: Double) -> String {
        if score >= 0.8 { return "You're well recovered. Great time for a hard session!" }
        if score >= 0.5 { return "Mostly recovered. Light to moderate training recommended." }
        if score >= 0.25 { return "Still recovering. Consider lighter work or different muscles." }
        return "Significant fatigue. A rest day would be beneficial."
    }

    static func timeAgoText(from date: Date) -> String {
        date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated))
    }
}
