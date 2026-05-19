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
}
