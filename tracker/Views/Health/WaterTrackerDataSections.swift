import SwiftUI

enum WaterTrackerDataSections {

    struct TimeBlock: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let ml: Double
        let color: Color
    }

    static func dailyTotals(
        allEntries: [WaterEntry],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(date: Date, ml: Double)] {
        (0..<days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { return nil }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let total = allEntries.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.milliliters }
            return (date: start, ml: total)
        }
    }

    static func weeklyStats(
        allEntries: [WaterEntry],
        days: Int,
        goalMl: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> (avg: Double, daysMetGoal: Int, totalDays: Int) {
        let totals = dailyTotals(allEntries: allEntries, days: days, now: now, calendar: calendar)
        guard !totals.isEmpty else { return (0, 0, 0) }
        let nonZeroDays = totals.filter { $0.ml > 0 }
        let avg = nonZeroDays.isEmpty ? 0 : nonZeroDays.map(\.ml).reduce(0, +) / Double(nonZeroDays.count)
        let metGoal = totals.filter { $0.ml >= goalMl }.count
        return (avg, metGoal, totals.count)
    }

    static func hydrationStreak(
        allEntries: [WaterEntry],
        todayTotalMl: Double,
        goalMl: Double,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: now)
        if todayTotalMl < goalMl {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while true {
            let dayStart = checkDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let dayTotal = allEntries.filter { $0.date >= dayStart && $0.date < dayEnd }.reduce(0) { $0 + $1.milliliters }
            if dayTotal >= goalMl {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else { break }
        }
        return streak
    }

    static func timeOfDayBreakdown(todayEntries: [WaterEntry], calendar: Calendar = .current) -> [TimeBlock] {
        var morning: Double = 0, afternoon: Double = 0, evening: Double = 0, night: Double = 0
        for entry in todayEntries {
            let hour = calendar.component(.hour, from: entry.date)
            switch hour {
            case 5..<12: morning += entry.milliliters
            case 12..<17: afternoon += entry.milliliters
            case 17..<21: evening += entry.milliliters
            default: night += entry.milliliters
            }
        }
        return [
            TimeBlock(label: "Morning", icon: "sunrise.fill", ml: morning, color: .orange),
            TimeBlock(label: "Afternoon", icon: "sun.max.fill", ml: afternoon, color: .yellow),
            TimeBlock(label: "Evening", icon: "sunset.fill", ml: evening, color: .indigo),
            TimeBlock(label: "Night", icon: "moon.fill", ml: night, color: .purple),
        ]
    }
}
