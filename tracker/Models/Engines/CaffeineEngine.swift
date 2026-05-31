import Foundation

/// Pure-value caffeine math. Extracted out of `HomeDashboardView`,
/// which had grown a binary search for the clear-time and a bedtime
/// suggester sitting directly inside the SwiftUI body file.
///
/// All inputs are immutable arrays + scalars; nothing here touches a
/// model context or HealthKit. Easy to unit-test in isolation.
enum CaffeineEngine {

    /// Total active caffeine (mg) at a given moment, summed across all
    /// recorded entries using each entry's exponential half-life decay.
    static func totalMg(at time: Date, entries: [CaffeineEntry], halfLifeHours: Double) -> Double {
        entries.reduce(0) { $0 + $1.remainingCaffeine(at: time, halfLifeHours: halfLifeHours) }
    }

    /// Estimated moment at which caffeine drops below the "effectively
    /// clear" threshold (25 mg). Returns nil when already below threshold.
    ///
    /// Implemented as a bounded binary search rather than a closed-form
    /// log because the entries decay independently — there's no analytic
    /// shortcut once you have ≥2 doses at different times.
    static func clearTime(from now: Date, entries: [CaffeineEntry], halfLifeHours: Double) -> Date? {
        let remaining = totalMg(at: now, entries: entries, halfLifeHours: halfLifeHours)
        guard remaining >= 25 else { return nil }

        var lo: TimeInterval = 0
        var hi: TimeInterval = 24 * 3600
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            let atMid = totalMg(at: now.addingTimeInterval(mid), entries: entries, halfLifeHours: halfLifeHours)
            if atMid > 25 { lo = mid } else { hi = mid }
        }
        return now.addingTimeInterval(hi)
    }

    /// Suggested bedtime — the user's default (22:00) shifted later if
    /// caffeine is still active at that time. The bool flag lets the UI
    /// indicate when the suggestion was driven by caffeine load rather
    /// than the standard target.
    static func suggestedBedtime(
        from now: Date,
        entries: [CaffeineEntry],
        halfLifeHours: Double,
        defaultHour: Int = 22
    ) -> (time: Date, delayedByCaffeine: Bool) {
        let calendar = Calendar.current
        var defaultBedtime = calendar.date(
            bySettingHour: defaultHour, minute: 0, second: 0,
            of: calendar.startOfDay(for: now)
        ) ?? now.addingTimeInterval(3600 * 4)

        if defaultBedtime < now {
            defaultBedtime = calendar.date(byAdding: .day, value: 1, to: defaultBedtime) ?? defaultBedtime
        }

        if let clear = clearTime(from: now, entries: entries, halfLifeHours: halfLifeHours),
           clear > defaultBedtime {
            return (clear, true)
        }
        return (defaultBedtime, false)
    }

    enum SleepReadiness: String {
        case readyForSleep
        case windingDown
        case elevated
        case tooStimulated

        static func level(forMg mg: Double) -> SleepReadiness {
            if mg < 25 { return .readyForSleep }
            if mg < 50 { return .windingDown }
            if mg < 100 { return .elevated }
            return .tooStimulated
        }
    }

    enum HistoryRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"

        var dayCount: Int { self == .week ? 7 : 30 }
    }

    struct DailyTotal: Identifiable {
        let date: Date
        let mg: Double
        var id: Date { date }
    }

    struct FrequentSource: Identifiable {
        let name: String
        let mg: Double
        let icon: String
        let count: Int
        var id: String { name }
    }

    struct TimeOfDaySlice: Identifiable {
        let period: String
        let icon: String
        let mg: Double
        let count: Int
        var id: String { period }
    }

    struct HistoryStats {
        let avgPerDay: Double
        let total: Double
        let daysTracked: Int
    }

    struct DecayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let mg: Double
    }

    struct PeakInfo {
        let peakTime: Date
        let peakMg: Double
    }

    static func todayLoggedMg(entries: [CaffeineEntry], now: Date = .now, calendar: Calendar = .current) -> Double {
        let startOfDay = calendar.startOfDay(for: now)
        return entries.filter { $0.date >= startOfDay }.reduce(0) { $0 + $1.milligrams }
    }

    static func dailyTotals(
        entries: [CaffeineEntry],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyTotal] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset -> DailyTotal? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let total = entries
                .filter { $0.date >= day && $0.date < nextDay }
                .reduce(0) { $0 + $1.milligrams }
            return DailyTotal(date: day, mg: total)
        }
    }

    static func historyStats(for dailyTotals: [DailyTotal]) -> HistoryStats {
        let daysWithData = dailyTotals.filter { $0.mg > 0 }.count
        let total = dailyTotals.reduce(0) { $0 + $1.mg }
        let avg = daysWithData > 0 ? total / Double(daysWithData) : 0
        return HistoryStats(avgPerDay: avg, total: total, daysTracked: daysWithData)
    }

    static func frequentSources(
        entries: [CaffeineEntry],
        lastDays: Int = 30,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [FrequentSource] {
        let cutoff = calendar.date(byAdding: .day, value: -lastDays, to: now) ?? now
        let last30 = entries.filter { $0.date > cutoff }
        var counts: [String: Int] = [:]
        for entry in last30 { counts[entry.source, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { source, count in
                if let preset = CaffeineEntry.presets.first(where: { $0.name == source }) {
                    return FrequentSource(name: preset.name, mg: preset.mg, icon: preset.icon, count: count)
                }
                let avg = last30.filter { $0.source == source }.map(\.milligrams).reduce(0, +) / Double(count)
                return FrequentSource(name: source, mg: avg, icon: "pill.fill", count: count)
            }
    }

    static func timeOfDayBreakdown(
        entries: [CaffeineEntry],
        lastDays: Int = 30,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [TimeOfDaySlice] {
        let cutoff = calendar.date(byAdding: .day, value: -lastDays, to: now) ?? now
        let last30 = entries.filter { $0.date > cutoff }
        var morning: (mg: Double, count: Int) = (0, 0)
        var afternoon: (mg: Double, count: Int) = (0, 0)
        var evening: (mg: Double, count: Int) = (0, 0)
        var night: (mg: Double, count: Int) = (0, 0)
        for entry in last30 {
            switch calendar.component(.hour, from: entry.date) {
            case 5..<12: morning.mg += entry.milligrams; morning.count += 1
            case 12..<17: afternoon.mg += entry.milligrams; afternoon.count += 1
            case 17..<21: evening.mg += entry.milligrams; evening.count += 1
            default: night.mg += entry.milligrams; night.count += 1
            }
        }
        return [
            TimeOfDaySlice(period: "Morning", icon: "sunrise.fill", mg: morning.mg, count: morning.count),
            TimeOfDaySlice(period: "Afternoon", icon: "sun.max.fill", mg: afternoon.mg, count: afternoon.count),
            TimeOfDaySlice(period: "Evening", icon: "sunset.fill", mg: evening.mg, count: evening.count),
            TimeOfDaySlice(period: "Night", icon: "moon.stars.fill", mg: night.mg, count: night.count),
        ]
    }

    static func caffeineFreeStreak(
        entries: [CaffeineEntry],
        maxLookback: Int = 90,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let today = calendar.startOfDay(for: now)
        var streak = 0
        for offset in 0..<maxLookback {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            if entries.contains(where: { $0.date >= day && $0.date < nextDay }) { break }
            streak += 1
        }
        return streak
    }

    static func daysSinceFreeDayText(
        entries: [CaffeineEntry],
        maxLookback: Int = 90,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> String? {
        let today = calendar.startOfDay(for: now)
        guard let todayEnd = calendar.date(byAdding: .day, value: 1, to: today) else { return nil }
        guard entries.contains(where: { $0.date >= today && $0.date < todayEnd }) else { return nil }
        for offset in 1..<maxLookback {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            if !entries.contains(where: { $0.date >= day && $0.date < nextDay }) {
                return offset == 1 ? "Yesterday" : "\(offset) days ago"
            }
        }
        return nil
    }

    static func peakCaffeineInfo(
        entries: [CaffeineEntry],
        halfLifeHours: Double,
        now: Date = .now
    ) -> PeakInfo? {
        let recentActive = entries.filter { $0.remainingCaffeine(at: now, halfLifeHours: halfLifeHours) > 1 }
        guard let latest = recentActive.first else { return nil }
        let peakTime = latest.date.addingTimeInterval(45 * 60)
        guard peakTime > now else { return nil }
        let peakMg = recentActive.reduce(0.0) { $0 + $1.remainingCaffeine(at: peakTime, halfLifeHours: halfLifeHours) }
        return PeakInfo(peakTime: peakTime, peakMg: peakMg)
    }

    static func decayCurveData(
        entries: [CaffeineEntry],
        halfLifeHours: Double,
        now: Date = .now,
        stepCount: Int = 48,
        stepSeconds: TimeInterval = 900
    ) -> [DecayPoint] {
        let recentEntries = entries.filter { $0.remainingCaffeine(at: now, halfLifeHours: halfLifeHours) > 0.1 }
        return (0...stepCount).map { i in
            let time = now.addingTimeInterval(Double(i) * stepSeconds)
            let total = recentEntries.reduce(0.0) { $0 + $1.remainingCaffeine(at: time, halfLifeHours: halfLifeHours) }
            return DecayPoint(date: time, mg: total)
        }
    }
}
