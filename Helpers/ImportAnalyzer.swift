import Foundation

/// Post-import "wow moment" analysis. Run over the freshly-parsed
/// `[ParsedWorkout]` immediately after a Strong/Hevy import lands,
/// produces an `ImportAnalysis` that drives the success sheet's
/// content — replacing the bland "Imported 184 workouts" alert
/// with concrete observations the engine pulled out of the user's
/// real history. The reviewer's pitch:
///
///     Imported:
///     - 184 workouts
///     - 63 exercises
///     - 22 PRs
///
///     Metricly noticed:
///     - Bench progress has stalled recently
///     - Pull volume is consistent
///     - Legs are trained less often than upper body
///
///     Recommended:
///     Start Adaptive Push Day
///
/// Pure — takes only the parsed data, no model context. That keeps
/// the analyzer unit-testable and lets it run before the rows are
/// even committed. The recommendation here is a best-effort pick
/// from the imported history; the full TodayPlanEngine integration
/// happens later when the user opens the home screen and the engine
/// runs against the now-committed data.
struct ImportAnalysis {
    let workoutCount: Int
    let exerciseCount: Int
    let totalSetCount: Int
    let dateRange: ClosedRange<Date>?
    let monthSpan: Int
    /// Number of exercises whose best estimated 1RM landed in the
    /// most recent half of their sessions — interpreted as "PRs the
    /// user is currently driving toward" rather than stale all-time
    /// tops. Requires at least 4 logged sessions of the exercise to
    /// count, so a one-off heavy day doesn't get flagged.
    let prCount: Int
    /// Most-frequently-trained exercise across the import.
    let topExercise: (name: String, hits: Int)?
    /// Muscle group with the highest total working-set volume
    /// (reps × weight). Includes inferred categories; cardio is
    /// excluded because it dominates by volume in users with run
    /// histories.
    let mostTrainedGroup: MuscleGroup?
    /// Trainable muscle group with the lowest volume (cardio + other
    /// excluded). nil when the import has no strength sets at all.
    let leastTrainedGroup: MuscleGroup?
    /// Best-effort starting recommendation: the most-frequent
    /// workout name in the imported history, plus a moderate
    /// intensity placeholder. Once the rows are committed and the
    /// home screen recomputes, the real TodayPlanEngine takes over.
    let recommendation: Recommendation?

    struct Recommendation: Equatable {
        let workoutName: String
        let intensity: TodayPlan.Intensity
    }
}

enum ImportAnalyzer {

    /// Compute an analysis over the parsed workouts. Tolerates empty
    /// input — every optional field becomes nil and the counts go to
    /// zero so the UI can still render without branching.
    static func analyze(_ workouts: [ParsedWorkout]) -> ImportAnalysis {
        let workoutCount = workouts.count
        let allExerciseNames = workouts.flatMap { w in
            w.exercises.map { $0.name.lowercased() }
        }
        let exerciseCount = Set(allExerciseNames).count
        let totalSetCount = workouts.reduce(0) { acc, w in
            acc + w.exercises.reduce(0) { $0 + $1.sets.count }
        }

        let sortedDates = workouts.map(\.startDate).sorted()
        let dateRange: ClosedRange<Date>?
        let monthSpan: Int
        if let first = sortedDates.first, let last = sortedDates.last, first <= last {
            dateRange = first ... last
            monthSpan = Calendar.current.dateComponents([.month], from: first, to: last).month ?? 0
        } else {
            dateRange = nil
            monthSpan = 0
        }

        // Top exercise — most-frequent across all workouts.
        let counts = Dictionary(grouping: allExerciseNames, by: { $0 })
            .mapValues { $0.count }
        let topExercise: (name: String, hits: Int)?
        if let top = counts.max(by: { $0.value < $1.value }) {
            // Pull the original-cased name from the source data.
            let displayName = workouts
                .flatMap(\.exercises)
                .first { $0.name.lowercased() == top.key }?.name ?? top.key.capitalized
            topExercise = (displayName, top.value)
        } else {
            topExercise = nil
        }

        let prCount = computePRCount(workouts)
        let groupVolumes = computeGroupVolumes(workouts)
        let mostTrainedGroup = groupVolumes.max(by: { $0.value < $1.value })?.key
        let leastTrainedGroup = groupVolumes
            .filter { $0.key != .cardio && $0.key != .other }
            .min(by: { $0.value < $1.value })?.key

        let recommendation: ImportAnalysis.Recommendation? = {
            let workoutNameCounts = Dictionary(
                grouping: workouts,
                by: { $0.title.lowercased() }
            ).mapValues { $0.count }
            guard let topName = workoutNameCounts.max(by: { $0.value < $1.value })?.key
            else { return nil }
            // Get the original casing back.
            let displayName = workouts
                .first { $0.title.lowercased() == topName }?.title ?? topName.capitalized
            return .init(workoutName: displayName, intensity: .moderate)
        }()

        return ImportAnalysis(
            workoutCount: workoutCount,
            exerciseCount: exerciseCount,
            totalSetCount: totalSetCount,
            dateRange: dateRange,
            monthSpan: monthSpan,
            prCount: prCount,
            topExercise: topExercise,
            mostTrainedGroup: mostTrainedGroup,
            leastTrainedGroup: leastTrainedGroup,
            recommendation: recommendation
        )
    }

    // MARK: - PR detection

    /// "Active PR" definition: for each exercise with ≥4 logged
    /// sessions, the best estimated 1RM across all sessions lands
    /// in the more recent half of the timeline. Interprets PRs as
    /// "still improving" rather than "stale all-time top" — a user
    /// whose bench peaked 3 years ago and hasn't matched it since
    /// shouldn't see "1 PR" on the import sheet.
    private static func computePRCount(_ workouts: [ParsedWorkout]) -> Int {
        struct SessionPeak { let date: Date; let top1RM: Double }
        var byExercise: [String: [SessionPeak]] = [:]

        for w in workouts {
            for ex in w.exercises {
                let workingSets = ex.sets.filter { !$0.isWarmUp && $0.weightKg > 0 }
                guard let topInSession = workingSets.map(estimated1RM(of:)).max(),
                      topInSession > 0 else { continue }
                byExercise[ex.name.lowercased(), default: []]
                    .append(SessionPeak(date: w.startDate, top1RM: topInSession))
            }
        }

        var prCount = 0
        for (_, history) in byExercise where history.count >= 4 {
            let sorted = history.sorted { $0.date < $1.date }
            guard let bestPeak = sorted.map(\.top1RM).max() else { continue }
            guard let bestIndex = sorted.firstIndex(where: { $0.top1RM == bestPeak })
            else { continue }
            let midpoint = sorted.count / 2
            if bestIndex >= midpoint { prCount += 1 }
        }
        return prCount
    }

    // MARK: - Volume by group

    /// Sum (reps × weight) for every working set, bucketed by the
    /// inferred muscle group of the exercise. Used to find the
    /// user's most-trained and least-trained groups.
    private static func computeGroupVolumes(_ workouts: [ParsedWorkout]) -> [MuscleGroup: Double] {
        var volumes: [MuscleGroup: Double] = [:]
        for w in workouts {
            for ex in w.exercises {
                // Fall back to .other when the inference can't pick
                // a group — better than dropping the volume entirely.
                let group = MuscleGroup.inferred(fromName: ex.name) ?? .other
                for s in ex.sets where !s.isWarmUp && s.weightKg > 0 {
                    volumes[group, default: 0] += Double(s.reps) * s.weightKg
                }
            }
        }
        return volumes
    }

    // MARK: - 1RM helper

    /// Epley estimated 1RM. Matches the implementation
    /// `PersonalInsightsEngine` uses; duplicated here because that
    /// helper is private to the engine and pulling the Epley constant
    /// across module boundaries isn't worth the dependency for one
    /// formula. Zero weight returns zero; single-rep sets short-circuit
    /// to the weight itself.
    private static func estimated1RM(of set: ParsedSet) -> Double {
        guard set.weightKg > 0 else { return 0 }
        let reps = max(1, set.reps)
        if reps == 1 { return set.weightKg }
        return set.weightKg * (1.0 + Double(reps) / 30.0)
    }
}
