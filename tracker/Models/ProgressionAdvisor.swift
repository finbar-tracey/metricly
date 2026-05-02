import SwiftUI

// MARK: - Data Types

enum ProgressionAction {
    case increase(suggestedWeight: Double) // kg
    case hold(reason: String)
    case deload(reason: String)
    case insufficient
}

struct ProgressionRecommendation {
    let action: ProgressionAction
    let headline: String
    let detail: String
    let confidence: Double // 0–1
}

struct SessionSummary {
    let date: Date
    let topWeight: Double   // kg
    let topReps: Int
    let avgRPE: Double?
    let estimated1RM: Double
}

// MARK: - Advisor Logic

enum ProgressionAdvisor {

    /// Weight increment in kg based on muscle group.
    static func increment(for group: MuscleGroup?) -> Double {
        switch group {
        case .legs: return 5.0
        default: return 2.5
        }
    }

    /// Build session summaries from an array of Exercise instances (newest first).
    static func buildSessions(from exercises: [Exercise]) -> [SessionSummary] {
        exercises.compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let working = exercise.sets.filter { !$0.isWarmUp }
            guard !working.isEmpty else { return nil }

            let topWeight = working.map(\.weight).max() ?? 0
            guard topWeight > 0 else { return nil }

            let topReps = working.filter { $0.weight == topWeight }.map(\.reps).max() ?? 0

            let rpeSets = working.compactMap(\.rpe)
            let avgRPE: Double? = rpeSets.count >= 1
                ? Double(rpeSets.reduce(0, +)) / Double(rpeSets.count)
                : nil

            let best1RM = working.map { set in
                let r = max(1, set.reps)
                return r == 1 ? set.weight : set.weight * (1.0 + Double(r) / 30.0)
            }.max() ?? topWeight

            return SessionSummary(
                date: date,
                topWeight: topWeight,
                topReps: topReps,
                avgRPE: avgRPE,
                estimated1RM: best1RM
            )
        }
    }

    /// Main recommendation engine.
    /// - Parameters:
    ///   - sessions: Array of `SessionSummary`, **newest first**.
    ///   - muscleGroup: The exercise's muscle group (used for weight increment).
    static func recommend(sessions: [SessionSummary], muscleGroup: MuscleGroup?) -> ProgressionRecommendation {
        guard sessions.count >= 2 else {
            return ProgressionRecommendation(
                action: .insufficient,
                headline: "Not enough data",
                detail: "Log at least 2 sessions to get a recommendation.",
                confidence: 0
            )
        }

        let latest = sessions[0]
        let previous = sessions[1]
        let inc = increment(for: muscleGroup)
        let suggested = latest.topWeight + inc

        // RPE-based path: need RPE data on both of the last 2 sessions
        if let rpe0 = latest.avgRPE, let rpe1 = previous.avgRPE {
            let avg = (rpe0 + rpe1) / 2.0

            if avg <= 7.5 {
                return ProgressionRecommendation(
                    action: .increase(suggestedWeight: suggested),
                    headline: "Ready to increase",
                    detail: "RPE averaging \(String(format: "%.1f", avg)) — room to grow.",
                    confidence: min(1.0, (8.0 - avg) / 3.0)
                )
            } else if avg < 9.0 {
                return ProgressionRecommendation(
                    action: .hold(reason: "productive"),
                    headline: "Hold steady",
                    detail: "RPE averaging \(String(format: "%.1f", avg)) — challenging but productive.",
                    confidence: 0.4
                )
            } else {
                return ProgressionRecommendation(
                    action: .deload(reason: "high RPE"),
                    headline: "Consider a deload",
                    detail: "RPE averaging \(String(format: "%.1f", avg)) — reduce weight to recover.",
                    confidence: 0.7
                )
            }
        }

        // No-RPE fallback: compare weight and rep trends
        let weightUp = latest.topWeight > previous.topWeight
        let repsUp = latest.topReps > previous.topReps && latest.topWeight >= previous.topWeight
        let weightDown = latest.topWeight < previous.topWeight
        let repsDown = latest.topReps < previous.topReps && latest.topWeight <= previous.topWeight
        let same = latest.topWeight == previous.topWeight && latest.topReps == previous.topReps

        if weightUp || repsUp {
            return ProgressionRecommendation(
                action: .increase(suggestedWeight: suggested),
                headline: "Ready to increase",
                detail: weightUp
                    ? "Weight went up last session — keep pushing."
                    : "More reps at the same weight — time to add load.",
                confidence: weightUp ? 0.8 : 0.65
            )
        }

        if same {
            return ProgressionRecommendation(
                action: .hold(reason: "plateau"),
                headline: "Hold steady",
                detail: "Same weight and reps — try adding a rep next time.",
                confidence: 0.4
            )
        }

        if weightDown || repsDown {
            // Check for sustained decline across 3+ sessions
            if sessions.count >= 3 {
                let older = sessions[2]
                let sustainedDecline = latest.topWeight < previous.topWeight
                    && previous.topWeight < older.topWeight
                if sustainedDecline {
                    let deloadWeight = max(0, latest.topWeight - inc)
                    return ProgressionRecommendation(
                        action: .deload(reason: "declining trend"),
                        headline: "Consider a deload",
                        detail: "Weight has declined over 3 sessions — drop to \(Int(deloadWeight)) kg and rebuild.",
                        confidence: 0.7
                    )
                }
            }

            return ProgressionRecommendation(
                action: .hold(reason: "minor dip"),
                headline: "Hold steady",
                detail: "Small dip last session — maintain and aim to match your best.",
                confidence: 0.35
            )
        }

        // Fallback
        return ProgressionRecommendation(
            action: .hold(reason: "mixed signals"),
            headline: "Hold steady",
            detail: "Mixed trends — keep training consistently.",
            confidence: 0.3
        )
    }
}

