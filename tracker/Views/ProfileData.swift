import SwiftUI

/// The static parts of the "You" dashboard (design_handoff_app, screen-profile.jsx),
/// derived from stored data. The learned baselines are async (HealthKit) and
/// thread in separately; this covers identity, goal, and connections.
struct ProfileData {

    struct GoalProgress {
        let exerciseName: String
        let currentKg: Double
        let targetKg: Double
        var fraction: Double { targetKg > 0 ? min(1, currentKg / targetKg) : 0 }
        /// Weeks to target at the recent rate of gain, or nil when we can't
        /// estimate honestly (no goal, already hit, or no recent progression).
        let etaWeeks: Int?
    }

    var initial: String
    var name: String
    var memberSince: String?
    var statLine: String
    var goal: GoalProgress?
    var appleHealthLinked: Bool
    var stravaLinked: Bool
    var unitLabel: String

    // MARK: - Build

    static func build(
        settings: UserSettings,
        finishedWorkouts: [Workout],
        bodyWeights: [BodyWeightEntry],
        liftGoals: [LiftGoal],
        appleHealthLinked: Bool,
        stravaLinked: Bool
    ) -> ProfileData {
        let name = settings.userName.isEmpty ? String(localized: "Athlete", comment: "Default display name on the profile when the user has not set one") : settings.userName
        let weightUnit: WeightUnit = settings.useKilograms ? .kg : .lbs

        return ProfileData(
            initial: name.first.map { String($0).uppercased() } ?? String(localized: "A", comment: "Avatar initial fallback when there is no name"),
            name: name,
            memberSince: memberSince(finishedWorkouts: finishedWorkouts),
            statLine: statLine(settings: settings, finishedWorkouts: finishedWorkouts,
                               bodyWeights: bodyWeights, weightUnit: weightUnit),
            goal: goal(liftGoals: liftGoals, finishedWorkouts: finishedWorkouts, weightUnit: weightUnit),
            appleHealthLinked: appleHealthLinked,
            stravaLinked: stravaLinked,
            unitLabel: weightUnit.label
        )
    }

    // MARK: - Identity

    private static func memberSince(finishedWorkouts: [Workout]) -> String? {
        guard let earliest = finishedWorkouts.map(\.date).min() else { return nil }
        let year = earliest.formatted(.dateTime.year())
        return String(localized: "Member since \(year)", comment: "Profile header; year of first logged workout (shown uppercase)")
    }

    private static func statLine(
        settings: UserSettings,
        finishedWorkouts: [Workout],
        bodyWeights: [BodyWeightEntry],
        weightUnit: WeightUnit
    ) -> String {
        var parts: [String] = []

        let count = finishedWorkouts.count
        if count > 0 { parts.append(String(localized: "\(count) sessions", comment: "Profile stat line: number of finished workouts (shown uppercase)")) }

        if let latest = bodyWeights.max(by: { $0.date < $1.date }), latest.weight > 0 {
            parts.append(weightUnit.formatShort(latest.weight))
        }

        // The user's own most-scheduled split, if they keep a weekly plan.
        let planNames = settings.weeklyPlan.values.filter { !$0.isEmpty }
        if let split = planNames.mostCommon() {
            parts.append(split)
        }

        return parts.isEmpty ? String(localized: "Learning your baselines", comment: "Profile stat line fallback (shown uppercase)") : parts.joined(separator: " · ")
    }

    // MARK: - Goal

    private static func goal(
        liftGoals: [LiftGoal],
        finishedWorkouts: [Workout],
        weightUnit: WeightUnit
    ) -> GoalProgress? {
        // The nearest-but-not-yet-hit goal — the one worth showing progress on.
        let active = liftGoals.filter { $0.achievedDate == nil && $0.targetWeight > 0 }
        guard !active.isEmpty else { return nil }

        let best: (goal: LiftGoal, current: Double)? = active
            .map { ($0, currentBest(for: $0.exerciseName, in: finishedWorkouts)) }
            .filter { $0.1 < $0.0.targetWeight }
            .max { ($0.1 / $0.0.targetWeight) < ($1.1 / $1.0.targetWeight) }

        guard let picked = best else { return nil }
        return GoalProgress(
            exerciseName: picked.goal.exerciseName,
            currentKg: picked.current,
            targetKg: picked.goal.targetWeight,
            etaWeeks: etaWeeks(
                exerciseName: picked.goal.exerciseName,
                current: picked.current,
                target: picked.goal.targetWeight,
                finishedWorkouts: finishedWorkouts
            )
        )
    }

    private static func currentBest(for exerciseName: String, in workouts: [Workout]) -> Double {
        workouts
            .flatMap(\.exercises)
            .filter { $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame }
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .map(\.weight)
            .max() ?? 0
    }

    /// Linear ETA from the last ~8 weeks of top sets. nil when there aren't two
    /// dated points or the trend is flat/negative — better no estimate than a
    /// made-up one.
    private static func etaWeeks(
        exerciseName: String,
        current: Double,
        target: Double,
        finishedWorkouts: [Workout]
    ) -> Int? {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .weekOfYear, value: -8, to: .now) ?? .distantPast
        let dated: [(date: Date, top: Double)] = finishedWorkouts
            .filter { $0.date >= cutoff }
            .compactMap { workout in
                let top = workout.exercises
                    .filter { $0.name.localizedCaseInsensitiveCompare(exerciseName) == .orderedSame }
                    .flatMap(\.sets).filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                return top > 0 ? (workout.date, top) : nil
            }
            .sorted { $0.date < $1.date }

        guard let first = dated.first, let last = dated.last,
              last.date > first.date, last.top > first.top else { return nil }

        let weeks = last.date.timeIntervalSince(first.date) / (7 * 86400)
        let ratePerWeek = (last.top - first.top) / weeks
        guard ratePerWeek > 0 else { return nil }

        let eta = (target - current) / ratePerWeek
        guard eta > 0, eta < 260 else { return nil }  // cap at ~5 years of nonsense
        return max(1, Int(eta.rounded()))
    }
}

private extension Array where Element: Hashable {
    /// The most frequent element, ties broken arbitrarily.
    func mostCommon() -> Element? {
        Dictionary(grouping: self, by: { $0 })
            .max { $0.value.count < $1.value.count }?
            .key
    }
}
