import Foundation

/// Pure body-weight trend math — moving average, domains, change.
enum BodyWeightEngine {

    struct TrendPoint: Identifiable {
        let id: Date
        var date: Date { id }
        let value: Double
    }

    struct DailyAverage: Identifiable {
        let date: Date
        let weightKg: Double
        var id: Date { date }
    }

    struct Summary {
        let lowestKg: Double?
        let highestKg: Double?
        let changeKg: Double?
    }

    static func chartEntries(
        from entries: [BodyWeightEntry],
        maxCount: Int = 90
    ) -> [BodyWeightEntry] {
        Array(entries.suffix(maxCount).reversed())
    }

    static func movingAverageTrend(
        chartEntries: [BodyWeightEntry],
        displayWeight: (Double) -> Double
    ) -> [TrendPoint] {
        let pts = chartEntries
        guard pts.count >= 2 else {
            return pts.map { TrendPoint(id: $0.date, value: displayWeight($0.weight)) }
        }
        return pts.indices.map { i in
            let lo = Swift.max(0, i - 6)
            let window = pts[lo...i]
            let avg = window.map { displayWeight($0.weight) }.reduce(0, +) / Double(window.count)
            return TrendPoint(id: pts[i].date, value: avg)
        }
    }

    static func chartYDomain(displayWeights: [Double]) -> ClosedRange<Double> {
        guard let minVal = displayWeights.min(), let maxVal = displayWeights.max() else { return 0...100 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    static func summary(
        entries: [BodyWeightEntry],
        changeLookbackDays: Int = 30,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Summary {
        let lowest = entries.map(\.weight).min()
        let highest = entries.map(\.weight).max()
        let change: Double? = {
            guard let latest = entries.first else { return nil }
            let cutoff = calendar.date(byAdding: .day, value: -changeLookbackDays, to: now) ?? .distantPast
            guard let oldest = entries.last(where: { $0.date <= cutoff }) ?? entries.last,
                  oldest.date != latest.date || oldest.weight != latest.weight else { return nil }
            return latest.weight - oldest.weight
        }()
        return Summary(lowestKg: lowest, highestKg: highest, changeKg: change)
    }

    static func dailyAverages(
        entries: [BodyWeightEntry],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyAverage] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset -> DailyAverage? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
            let dayEntries = entries.filter { $0.date >= day && $0.date < nextDay }
            guard !dayEntries.isEmpty else { return DailyAverage(date: day, weightKg: 0) }
            let avg = dayEntries.map(\.weight).reduce(0, +) / Double(dayEntries.count)
            return DailyAverage(date: day, weightKg: avg)
        }
    }
}
