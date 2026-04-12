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
    ///   - now: Injectable for testability.
    static func evaluate(
        workouts: [Workout],
        health: HealthSignals = .init(),
        now: Date = .now
    ) -> RecoveryResult {
        let healthMultiplier = computeHealthMultiplier(health: health)

        let muscleResults: [MuscleFatigueResult] = trainableGroups.map { group in
            computeMuscleFatigue(
                for: group,
                workouts: workouts,
                health: health,
                healthMultiplier: healthMultiplier,
                now: now
            )
        }

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

    static func readinessColor(_ score: Double) -> Color {
        freshnessColor(score)
    }

    static func readinessLabel(_ score: Double) -> String {
        if score >= 0.8 { return "You're well recovered. Great time for a hard session!" }
        if score >= 0.5 { return "Mostly recovered. Light to moderate training recommended." }
        if score >= 0.25 { return "Still recovering. Consider lighter work or different muscles." }
        return "Significant fatigue. A rest day would be beneficial."
    }

    static func timeAgoText(from date: Date) -> String {
        let hours = Int(Date.now.timeIntervalSince(date) / 3600)
        if hours < 1 { return "Just now" }
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        if days == 1 { return "Yesterday" }
        return "\(days) days ago"
    }
}
