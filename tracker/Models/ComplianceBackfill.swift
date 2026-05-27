import Foundation
import SwiftData

/// Walks recent days, classifies the user's actual training intensity,
/// and persists one `PlanComplianceEvent` per day.
///
/// Idempotent — events are keyed by `startOfDay` and the backfill skips
/// days that already have one. Runs on every foreground (cheap; reads
/// a 14-day window of in-memory @Query results).
enum ComplianceBackfill {

    /// How many past days to consider when filling in events. Matches
    /// `TodayPlanStore.historyLimit` so we never need a plan we threw
    /// away. Today is excluded — that's not over yet.
    static let lookbackDays: Int = 7

    /// Run the backfill against a model context. Caller passes the
    /// already-queried workouts + cardio so we don't duplicate fetches.
    @MainActor
    static func run(
        workouts: [Workout],
        cardioSessions: [CardioSession],
        existingEvents: [PlanComplianceEvent],
        in context: ModelContext,
        now: Date = .now
    ) {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        let existingDays = Set(existingEvents.map { cal.startOfDay(for: $0.day) })

        for offset in 1...lookbackDays {
            guard let day = cal.date(byAdding: .day, value: -offset, to: today) else { continue }
            let startOfDay = cal.startOfDay(for: day)
            // Skip days we already recorded.
            if existingDays.contains(startOfDay) { continue }

            let actual = classifyActualIntensity(
                on: day,
                workouts: workouts,
                cardioSessions: cardioSessions,
                calendar: cal
            )
            let suggested = TodayPlanStore.plan(on: day)?.intensity
            let complied: Bool = {
                guard let s = suggested else {
                    // No plan was cached for that day — neutral; don't
                    // mark as non-compliance (the user may have followed
                    // a suggestion we just don't have a record of).
                    return true
                }
                return s.matches(actual)
            }()

            let event = PlanComplianceEvent(
                day: startOfDay,
                suggested: suggested,
                actual: actual,
                complied: complied
            )
            context.insert(event)
        }

        try? context.save()
    }

    // MARK: - Classifier
    //
    // Same intensity buckets the engine uses, but inferred from observed
    // behaviour rather than recommended. Tuning is deliberately
    // forgiving — we'd rather under-flag non-compliance than scold a
    // user for a 20-minute light session on a moderate day.

    /// Map workouts + cardio on a day to one of `rest / light / moderate / hard`.
    static func classifyActualIntensity(
        on day: Date,
        workouts: [Workout],
        cardioSessions: [CardioSession],
        calendar: Calendar = .current
    ) -> TodayPlan.Intensity {
        let start = calendar.startOfDay(for: day)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return .rest }

        let dayWorkouts = workouts.filter { $0.date >= start && $0.date < end && $0.endTime != nil }
        let dayCardio = cardioSessions.filter { $0.date >= start && $0.date < end }

        // No activity → rest day
        if dayWorkouts.isEmpty && dayCardio.isEmpty { return .rest }

        // Compute total working sets + total volume
        let totalSets = dayWorkouts.reduce(0) { sum, w in
            sum + w.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
        }
        let totalVolumeKg = dayWorkouts.reduce(0.0) { $0 + $1.totalVolumeKg() }
        let cardioMinutes = dayCardio.reduce(0.0) { $0 + ($1.durationSeconds / 60) }

        // Heavy = 20+ working sets OR 2000+ kg volume OR 60+ min cardio
        if totalSets >= 20 || totalVolumeKg >= 2000 || cardioMinutes >= 60 {
            return .hard
        }
        // Light = ≤ 8 sets and ≤ 30 min cardio
        if totalSets <= 8 && cardioMinutes <= 30 {
            return .light
        }
        return .moderate
    }
}
