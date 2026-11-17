import SwiftUI

/// Everything `TrendsView` renders, derived from the user's finished workouts
/// (plus a HealthKit HRV series threaded in separately, since that's async).
/// Presentation over history — no new engine.
struct TrendsData {

    struct Stat: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let unit: String
        let decimals: Int
        let sub: String
        let tone: Color
        var spokenValue: String { value.formatted(.number.precision(.fractionLength(decimals))) }
    }

    struct WeekBar: Identifiable {
        let id = UUID()
        /// Volume in thousands of the user's unit.
        let volumeK: Double
        let isCurrent: Bool
        /// First day of the week the bar covers (for VoiceOver).
        let weekStart: Date
    }

    struct PRRow: Identifiable {
        let id = UUID()
        let name: String
        let detail: String
        let delta: String
        let when: String
    }

    var isEmpty: Bool
    var verdictA: String
    var verdictB: String
    var subline: String
    var stats: [Stat]
    var weeklyVolume: [WeekBar]
    var recentPRs: [PRRow]

    // MARK: - Build

    static func build(finishedWorkouts: [Workout], currentStreak: Int, weightUnit: WeightUnit) -> TrendsData {
        let finished = finishedWorkouts.filter(\.isFinished)
        guard !finished.isEmpty else {
            return TrendsData(
                isEmpty: true,
                verdictA: String(localized: "Day", comment: "Trends empty-state headline, first word (reads \"Day one.\")"),
                verdictB: String(localized: "one.", comment: "Trends empty-state headline, second word (reads \"Day one.\")"),
                subline: String(localized: "Log your first session and the engine starts learning you — baselines, load, readiness.", comment: "Trends empty-state subline"),
                stats: [], weeklyVolume: [], recentPRs: []
            )
        }

        let weeks = weeklyVolume(finished: finished, weightUnit: weightUnit)
        let (verdictB, subline) = trend(weeks: weeks)

        return TrendsData(
            isEmpty: false,
            verdictA: String(localized: "Trending", comment: "Trends headline, first word (reads \"Trending up.\")"),
            verdictB: verdictB,
            subline: subline,
            stats: stats(finished: finished, currentStreak: currentStreak, weightUnit: weightUnit),
            weeklyVolume: weeks,
            recentPRs: recentPRs(finished: finished, weightUnit: weightUnit)
        )
    }

    // MARK: - Weekly volume

    private static func weeklyVolume(finished: [Workout], weightUnit: WeightUnit) -> [WeekBar] {
        let cal = Calendar.current
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }

        // Eight buckets ending on the current week; empty weeks stay in as zeros
        // so a lay-off reads as a dip, not a gap.
        return (0..<8).reversed().map { offset -> WeekBar in
            let start = cal.date(byAdding: .weekOfYear, value: -offset, to: thisWeekStart) ?? thisWeekStart
            let end = cal.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
            let volumeKg = finished
                .filter { $0.date >= start && $0.date < end }
                .reduce(0.0) { $0 + $1.totalVolumeKg() }
            return WeekBar(volumeK: weightUnit.display(volumeKg) / 1000, isCurrent: offset == 0, weekStart: start)
        }
    }

    private static func trend(weeks: [WeekBar]) -> (verdictB: String, subline: String) {
        // Compare the last four weeks against the prior four — enough to smooth
        // a single big or missed session.
        guard weeks.count >= 8 else {
            return (String(localized: "up.", comment: "Trends verdict: volume rising"), String(localized: "Every session sharpens the picture.", comment: "Trends subline when under 8 weeks of data"))
        }
        let recent = weeks.suffix(4).reduce(0.0) { $0 + $1.volumeK }
        let prior = weeks.prefix(4).reduce(0.0) { $0 + $1.volumeK }
        if prior <= 0 {
            return (String(localized: "up.", comment: "Trends verdict: volume rising"), String(localized: "Volume building from the ground up — keep stacking sessions.", comment: "Trends subline when prior block had no volume"))
        }
        let change = (recent - prior) / prior
        if change >= 0.05 {
            return (String(localized: "up.", comment: "Trends verdict: volume rising"), String(localized: "Volume climbing over the last month — best block of the eight.", comment: "Trends subline: volume up over last 4 weeks vs prior 4"))
        }
        if change <= -0.05 {
            return (String(localized: "down.", comment: "Trends verdict: volume falling"), String(localized: "Lighter month — a deliberate deload or a dip to close?", comment: "Trends subline: volume down over last 4 weeks vs prior 4"))
        }
        return (String(localized: "steady.", comment: "Trends verdict: volume flat"), String(localized: "Holding volume week to week — consistency is its own progress.", comment: "Trends subline: volume flat"))
    }

    // MARK: - Stats

    private static func stats(finished: [Workout], currentStreak: Int, weightUnit: WeightUnit) -> [Stat] {
        let cal = Calendar.current
        let blockStart = cal.date(byAdding: .weekOfYear, value: -8, to: .now) ?? .distantPast
        let block = finished.filter { $0.date >= blockStart }
        let volumeKg = block.reduce(0.0) { $0 + $1.totalVolumeKg() }
        let volumeK = weightUnit.display(volumeKg) / 1000
        let volumeUnit = "k·\(weightUnit.label)"

        var stats: [Stat] = [
            Stat(label: String(localized: "Total volume", comment: "Trends stat tile label (shown uppercase)"), value: volumeK, unit: volumeUnit, decimals: 0,
                 sub: String(localized: "last 8 weeks", comment: "Trends stat tile caption"), tone: AppTheme.Dark.Signal.recovery),
            Stat(label: String(localized: "Sessions", comment: "Trends stat tile label (shown uppercase)"), value: Double(block.count), unit: String(localized: "done", comment: "Trends stat unit: sessions completed"), decimals: 0,
                 sub: String(localized: "logged this block", comment: "Trends stat tile caption"), tone: AppTheme.Dark.text)
        ]

        // A recovery-forward tile when RPE exists (the readiness story), else the
        // PR count — always a real number, never a fabricated "avg recovery".
        let rpes = block.flatMap(\.exercises).flatMap(\.sets).filter { !$0.isWarmUp }.compactMap(\.rpe)
        if !rpes.isEmpty {
            let avg = Double(rpes.reduce(0, +)) / Double(rpes.count)
            stats.append(Stat(label: String(localized: "Avg RPE", comment: "Trends stat tile label (shown uppercase)"), value: avg, unit: "/10", decimals: 1,
                              sub: String(localized: "effort logged", comment: "Trends stat tile caption"), tone: AppTheme.Dark.Signal.caution))
        } else {
            let prCount = recentPRs(finished: block, weightUnit: weightUnit).count
            stats.append(Stat(label: String(localized: "PRs", comment: "Trends stat tile label: personal records (shown uppercase)"), value: Double(prCount), unit: String(localized: "new", comment: "Trends stat unit: new personal records"), decimals: 0,
                              sub: String(localized: "this block", comment: "Trends stat tile caption"), tone: AppTheme.Dark.Signal.caution))
        }

        stats.append(Stat(label: String(localized: "Streak", comment: "Trends stat tile label (shown uppercase)"), value: Double(currentStreak), unit: currentStreak == 1 ? String(localized: "day", comment: "Singular day unit") : String(localized: "days", comment: "Plural days unit"), decimals: 0,
                          sub: currentStreak > 0 ? String(localized: "keep it lit", comment: "Trends streak caption when active") : String(localized: "start today", comment: "Trends streak caption when zero"), tone: AppTheme.Dark.text))
        return stats
    }

    // MARK: - Recent PRs

    /// Walks history oldest→newest, tracking a running max per exercise. Each
    /// time a working set beats the prior best, that's a PR — the most recent
    /// three are the ones worth showing.
    static func recentPRs(finished: [Workout], weightUnit: WeightUnit) -> [PRRow] {
        let chronological = finished.sorted { $0.date < $1.date }
        var best: [String: Double] = [:]
        var events: [(name: String, weight: Double, delta: Double, date: Date)] = []

        for workout in chronological {
            for exercise in workout.exercises {
                let top = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                guard top > 0 else { continue }
                let key = exercise.name.lowercased()
                if let prior = best[key] {
                    if top > prior {
                        events.append((exercise.name, top, top - prior, workout.date))
                        best[key] = top
                    }
                } else {
                    // First time we see an exercise isn't a "PR" worth trumpeting.
                    best[key] = top
                }
            }
        }

        return events.suffix(3).reversed().map { event in
            PRRow(
                name: event.name,
                detail: weightUnit.formatShort(event.weight),
                delta: "+\(weightUnit.formatShort(event.delta))",
                when: event.date.formatted(.dateTime.weekday(.abbreviated))
            )
        }
    }
}
