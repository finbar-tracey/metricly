import Foundation
import SwiftData

/// Translates a `TodayPlan` into concrete workout-level edits — the
/// "Apply Adjustments" feature. The plan emits user-facing copy
/// (`adjustments: [String]`) and structural hints (`avoidGroups`,
/// `intensity`); this helper turns those into actual mutations on a
/// `Workout` while being conservative about data the user has already
/// logged.
///
/// Two-phase API: `preview(plan:on:)` returns a `Preview` summarising
/// what *would* change — used to drive a confirmation alert — and
/// `apply(plan:to:in:)` performs the same change in a SwiftData
/// context. Both phases share the same selection logic so the alert
/// and the actual result can't drift apart.
///
/// Safety rules:
///  - Never delete an exercise that has any logged sets (any set with
///    `reps > 0 || weight > 0 || isCardio`).
///  - Never delete a logged set. Only trailing *blank* working sets
///    are eligible for removal.
///  - Never remove the last working set on an exercise — dropping a
///    light set is fine; dropping the only set isn't.
enum TodayPlanApply {

    // MARK: - Preview

    struct Preview {
        /// Exercises that will be removed (category in `avoidGroups`,
        /// no logged sets). Ordered by display order.
        let exercisesToRemove: [Exercise]
        /// Exercises that will lose one trailing blank working set.
        /// Ordered by display order. Same exercise only appears once.
        let exercisesToTrim: [Exercise]

        var isEmpty: Bool { exercisesToRemove.isEmpty && exercisesToTrim.isEmpty }

        /// One-sentence summary suitable for a confirmation alert.
        var summary: String {
            var parts: [String] = []
            if !exercisesToRemove.isEmpty {
                let n = exercisesToRemove.count
                parts.append("remove \(n) exercise\(n == 1 ? "" : "s")")
            }
            if !exercisesToTrim.isEmpty {
                let n = exercisesToTrim.count
                parts.append("drop 1 set from \(n) exercise\(n == 1 ? "" : "s")")
            }
            guard !parts.isEmpty else { return "Workout already aligns with today's plan." }
            return "This will \(parts.joined(separator: " and "))."
        }
    }

    /// Compute (but do not perform) the changes that `apply` would make.
    static func preview(plan: TodayPlan, on workout: Workout) -> Preview {
        // Skip finished workouts and templates — applying adjustments to
        // either makes no sense.
        guard !workout.isFinished, !workout.isTemplate else {
            return Preview(exercisesToRemove: [], exercisesToTrim: [])
        }

        let avoid = Set(plan.avoidGroups)
        let sorted = workout.exercises.sorted { $0.order < $1.order }

        var toRemove: [Exercise] = []
        var toTrim: [Exercise] = []

        for ex in sorted {
            if let cat = ex.category, avoid.contains(cat), !exerciseHasLoggedSets(ex) {
                toRemove.append(ex)
                continue
            }
            // Only the .light intensity trims sets — moderate/hard leave
            // volume alone, rest day doesn't apply (you're not training).
            if plan.intensity == .light, trimCandidate(in: ex) != nil {
                toTrim.append(ex)
            }
        }

        return Preview(exercisesToRemove: toRemove, exercisesToTrim: toTrim)
    }

    // MARK: - Apply

    /// Perform the changes from `preview` on `workout`. Caller is
    /// responsible for saving the context afterwards (so a single
    /// save batches well with other edits).
    @discardableResult
    static func apply(plan: TodayPlan, to workout: Workout, in context: ModelContext) -> Preview {
        let preview = preview(plan: plan, on: workout)
        for ex in preview.exercisesToRemove {
            context.delete(ex)
        }
        for ex in preview.exercisesToTrim {
            if let blank = trimCandidate(in: ex) {
                context.delete(blank)
            }
        }
        return preview
    }

    // MARK: - Internals

    private static func exerciseHasLoggedSets(_ ex: Exercise) -> Bool {
        ex.sets.contains { $0.reps > 0 || $0.weight > 0 || $0.isCardio }
    }

    /// A trailing blank working set that's safe to drop, or `nil`. Only
    /// returns a set if the exercise still has 2+ working sets after
    /// removal so we never zero out an exercise.
    private static func trimCandidate(in ex: Exercise) -> ExerciseSet? {
        let working = ex.sets.filter { !$0.isWarmUp }
        guard working.count >= 2 else { return nil }
        // Last working set, only if blank — never touch logged data.
        guard let last = working.last,
              last.reps == 0, last.weight == 0, !last.isCardio else { return nil }
        return last
    }
}
