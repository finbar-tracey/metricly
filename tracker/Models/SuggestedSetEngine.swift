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
        // Don't apply progression mid-session — that's noisy.
        if let lastWorkingThisSession = exercise.sets.last(where: { !$0.isWarmUp && $0.weight > 0 }) {
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
}
