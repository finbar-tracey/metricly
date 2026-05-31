import Foundation

/// Today's water intake vs goal — shared by Home and Health hub.
struct HydrationSummary: Equatable {
    let todayMl: Double
    let goalMl: Double

    var progress: Double {
        goalMl > 0 ? min(1.0, todayMl / goalMl) : 0
    }

    static func make(entries: [WaterEntry], goalMl: Int, on date: Date = .now) -> HydrationSummary {
        let start = Calendar.current.startOfDay(for: date)
        let today = entries.filter { $0.date >= start }.reduce(0.0) { $0 + $1.milliliters }
        return HydrationSummary(todayMl: today, goalMl: Double(goalMl))
    }
}
