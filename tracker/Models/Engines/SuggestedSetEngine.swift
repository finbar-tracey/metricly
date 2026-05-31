import Foundation
import SwiftData

/// What the user should do next on a given exercise — concrete weight + reps,
/// plus reasoning. Combines `ProgressionAdvisor` with within-session state.
struct SuggestedSet: Equatable {

    enum Source: String {
        /// The exercise has no past history; we fell back to the user's last
        /// in-session set.
        case repeatInSession
        /// Forward-looking: ProgressionAdvisor suggested adding weight or reps.
        case progression
        /// ProgressionAdvisor said deload — reducing weight from the user's
        /// last-session top set.
        case deload
        /// No past history at all; user must enter from scratch.
        case fresh
        /// Within-session coaching driven by the just-logged set's RPE.
        /// Only used when the user has logged RPE on the previous set.
        case rpeCoach
    }

    let reps: Int
    let weight: Double           // kg
    let isWarmUp: Bool
    let source: Source
    /// Short user-facing label, e.g. "Add weight", "Repeat last", "Add a rep".
    let label: String
    /// Plain-English reasoning (one line).
    let reasoning: String
    /// Confidence in the recommendation 0...1.
    let confidence: Double
}

enum SuggestedSetEngine {

    /// Suggest the next set for `exercise`. `history` should be all logged
    /// instances of this same exercise across the user's history (any order;
    /// we sort and filter internally).
    ///
    /// Returns nil only when there is no history at all and no in-session
    /// sets — i.e. the user is logging this exercise for the very first time.
    static func suggestNextSet(for exercise: Exercise, history: [Exercise]) -> SuggestedSet? {
        // Within-session: if the user has already logged a working set in this
        // exercise instance, the natural next move is to repeat or extend it.
        // Without RPE we stick to "repeat last" — noisy advice from a single
        // set is worse than no advice. With RPE we have an honest signal
        // about how the set felt and can be more useful.
        if let lastWorkingThisSession = exercise.sets.last(where: { !$0.isWarmUp && $0.weight > 0 }) {
            if let coached = rpeCoachedSuggestion(after: lastWorkingThisSession,
                                                  for: exercise) {
                return coached
            }
            return SuggestedSet(
                reps: lastWorkingThisSession.reps,
                weight: lastWorkingThisSession.weight,
                isWarmUp: false,
                source: .repeatInSession,
                label: "Repeat last",
                reasoning: "Match your last set this session",
                confidence: 0.7
            )
        }

        // Out-of-session: pull from past history. Exclude the current exercise
        // instance (it might be empty, or have warm-ups only).
        let pastHistory = history
            .filter { $0.persistentModelID != exercise.persistentModelID }
            .filter { !($0.workout?.isTemplate ?? true) && !$0.sets.isEmpty }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }

        guard let lastPastSession = pastHistory.first,
              let lastWorkingPast = lastPastSession.sets.last(where: { !$0.isWarmUp && $0.weight > 0 })
        else {
            return nil
        }

        // Need at least two past sessions for a forward-looking recommendation.
        let sessions = ProgressionAdvisor.buildSessions(from: pastHistory)
        if sessions.count >= 2 {
            let rec = ProgressionAdvisor.recommend(sessions: sessions, muscleGroup: exercise.category)
            switch rec.action {
            case .increase(let suggestedKg):
                return SuggestedSet(
                    reps: lastWorkingPast.reps,
                    weight: suggestedKg,
                    isWarmUp: false,
                    source: .progression,
                    label: "Add weight",
                    reasoning: rec.detail,
                    confidence: rec.confidence
                )
            case .hold:
                // "Hold" with steady RPE → try one more rep at the same weight.
                return SuggestedSet(
                    reps: lastWorkingPast.reps + 1,
                    weight: lastWorkingPast.weight,
                    isWarmUp: false,
                    source: .progression,
                    label: "Add a rep",
                    reasoning: rec.detail,
                    confidence: 0.5
                )
            case .deload:
                let inc = ProgressionAdvisor.increment(for: exercise.category)
                return SuggestedSet(
                    reps: lastWorkingPast.reps,
                    weight: max(0, lastWorkingPast.weight - inc),
                    isWarmUp: false,
                    source: .deload,
                    label: "Deload",
                    reasoning: rec.detail,
                    confidence: rec.confidence
                )
            case .insufficient:
                break   // Fall through to repeat-last
            }
        }

        // Fallback: repeat last session's working set.
        return SuggestedSet(
            reps: lastWorkingPast.reps,
            weight: lastWorkingPast.weight,
            isWarmUp: false,
            source: .repeatInSession,
            label: "Repeat last",
            reasoning: "Same as your last working set",
            confidence: 0.4
        )
    }

    // MARK: - Within-session RPE coaching
    //
    // Adjust the next-set target based on how the last working set felt.
    // Returns nil when there's no RPE on the previous set — caller should
    // fall back to "repeat last", which is the safe default.
    //
    // Rule of thumb the heuristics encode:
    //   RPE ≤ 6  → easy. Push one more rep, or +1 kg if user has stacked
    //              two consecutive light sets.
    //   RPE 7   → just-right. Match it.
    //   RPE 8   → working hard. Match it; this is the target zone.
    //   RPE 9   → near failure. Hold reps but flag that the user is
    //              approaching their limit.
    //   RPE 10  → failure. Suggest dropping a rep or calling it the top set.
    //
    // We're deliberately conservative — small adjustments only, and only
    // when the signal is unambiguous. The user can always override.
    private static func rpeCoachedSuggestion(after lastSet: ExerciseSet,
                                             for exercise: Exercise) -> SuggestedSet? {
        guard let rpe = lastSet.rpe else { return nil }

        // Look at the prior working set too — two-in-a-row easy means a
        // weight bump is warranted, not just a rep bump.
        let working = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        let priorWorking = working.dropLast().last
        let priorRPE = priorWorking?.rpe

        let weight = lastSet.weight
        let reps = lastSet.reps
        let inc = ProgressionAdvisor.increment(for: exercise.category)
        let setCountSoFar = working.count

        switch rpe {
        case ...6:
            // Two consecutive easy sets → time to add load.
            if let prior = priorRPE, prior <= 6 {
                return SuggestedSet(
                    reps: reps,
                    weight: weight + inc,
                    isWarmUp: false,
                    source: .rpeCoach,
                    label: "Add weight",
                    reasoning: "Two sets at RPE \(rpe) — you have room.",
                    confidence: 0.8
                )
            }
            return SuggestedSet(
                reps: reps + 1,
                weight: weight,
                isWarmUp: false,
                source: .rpeCoach,
                label: "Push +1 rep",
                reasoning: "Last set was easy (RPE \(rpe)). Squeeze out one more.",
                confidence: 0.75
            )
        case 7:
            return SuggestedSet(
                reps: reps,
                weight: weight,
                isWarmUp: false,
                source: .rpeCoach,
                label: "Match it",
                reasoning: "RPE 7 is the right zone — repeat.",
                confidence: 0.8
            )
        case 8:
            return SuggestedSet(
                reps: reps,
                weight: weight,
                isWarmUp: false,
                source: .rpeCoach,
                label: "Match it",
                reasoning: "RPE 8 — working hard. Hold the line.",
                confidence: 0.8
            )
        case 9:
            return SuggestedSet(
                reps: reps,
                weight: weight,
                isWarmUp: false,
                source: .rpeCoach,
                label: "Last hard set",
                reasoning: "RPE 9 — one more like this, then back off.",
                confidence: 0.7
            )
        default: // RPE 10+
            // After a failure set, recommend cutting one rep — or calling it
            // if the user already has a respectable set count.
            if setCountSoFar >= 3 {
                return SuggestedSet(
                    reps: max(1, reps - 2),
                    weight: weight,
                    isWarmUp: false,
                    source: .rpeCoach,
                    label: "Call it",
                    reasoning: "RPE 10 after \(setCountSoFar) sets. Today's top set is done.",
                    confidence: 0.7
                )
            }
            return SuggestedSet(
                reps: max(1, reps - 1),
                weight: weight,
                isWarmUp: false,
                source: .rpeCoach,
                label: "Drop a rep",
                reasoning: "RPE 10 — pull back one rep to keep the set quality.",
                confidence: 0.7
            )
        }
    }
}
