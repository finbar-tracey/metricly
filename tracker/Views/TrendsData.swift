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
        var spokenValue: String { String(format: "%.\(decimals)f", value) }
    }

    struct WeekBar: Identifiable {
        let id = UUID()
        /// Volume in thousands of the user's unit.
        let volumeK: Double
        let isCurrent: Bool
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
                verdictA: "Day", verdictB: "one.",
                subline: "Log your first session and the engine starts learning you — baselines, load, readiness.",
                stats: [], weeklyVolume: [], recentPRs: []
            )
        }

        let weeks = weeklyVolume(finished: finished, weightUnit: weightUnit)
        let (verdictB, subline) = trend(weeks: weeks)

        return TrendsData(
            isEmpty: false,
            verdictA: "Trending",
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
            return WeekBar(volumeK: weightUnit.display(volumeKg) / 1000, isCurrent: offset == 0)
        }
    }

    private static func trend(weeks: [WeekBar]) -> (verdictB: String, subline: String) {
        // Compare the last four weeks against the prior four — enough to smooth
        // a single big or missed session.
        guard weeks.count >= 8 else {
            return ("up.", "Every session sharpens the picture.")
        }
        let recent = weeks.suffix(4).reduce(0.0) { $0 + $1.volumeK }
        let prior = weeks.prefix(4).reduce(0.0) { $0 + $1.volumeK }
        if prior <= 0 {
            return ("up.", "Volume building from the ground up — keep stacking sessions.")
        }
        let change = (recent - prior) / prior
        if change >= 0.05 {
            return ("up.", "Volume climbing over the last month — best block of the eight.")
        }
        if change <= -0.05 {
            return ("down.", "Lighter month — a deliberate deload or a dip to close?")
        }
        return ("steady.", "Holding volume week to week — consistency is its own progress.")
    }

    // MARK: - Stats

    private static func stats(finished: [Workout], currentStreak: Int, weightUnit: WeightUnit) -> [Stat] {
        let cal = Calendar.current
        let blockStart = cal.date(byAdding: .weekOfYear, value: -8, to: .now) ?? .distantPast
        let block = finished.filter { $0.date >= blockStart }
        let volumeKg = block.reduce(0.0) { $0 + $1.totalVolumeKg() }
        let volumeK = weightUnit.display(volumeKg) / 1000
        let volumeUnit = weightUnit == .kg ? "k·kg" : "k·lb"

        var stats: [Stat] = [
            Stat(label: "TOTAL VOLUME", value: volumeK, unit: volumeUnit, decimals: 0,
                 sub: "last 8 weeks", tone: AppTheme.Dark.Signal.recovery),
            Stat(label: "SESSIONS", value: Double(block.count), unit: "done", decimals: 0,
                 sub: "logged this block", tone: AppTheme.Dark.text)
        ]

        // A recovery-forward tile when RPE exists (the readiness story), else the
        // PR count — always a real number, never a fabricated "avg recovery".
        let rpes = block.flatMap(\.exercises).flatMap(\.sets).filter { !$0.isWarmUp }.compactMap(\.rpe)
        if !rpes.isEmpty {
            let avg = Double(rpes.reduce(0, +)) / Double(rpes.count)
            stats.append(Stat(label: "AVG RPE", value: avg, unit: "/10", decimals: 1,
                              sub: "effort logged", tone: AppTheme.Dark.Signal.caution))
        } else {
            let prCount = recentPRs(finished: block, weightUnit: weightUnit).count
            stats.append(Stat(label: "PRS", value: Double(prCount), unit: "new", decimals: 0,
                              sub: "this block", tone: AppTheme.Dark.Signal.caution))
        }

        stats.append(Stat(label: "STREAK", value: Double(currentStreak), unit: currentStreak == 1 ? "day" : "days", decimals: 0,
                          sub: currentStreak > 0 ? "keep it lit" : "start today", tone: AppTheme.Dark.text))
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
                when: event.date.formatted(.dateTime.weekday(.abbreviated)).uppercased()
            )
        }
    }
}
