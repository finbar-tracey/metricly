import Foundation

/// Pure creatine tracking math — streaks, compliance, chart buckets.
enum CreatineEngine {

    enum HistoryRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"

        var dayCount: Int { self == .week ? 7 : 30 }
    }

    struct DayStatus: Identifiable {
        let date: Date
        let taken: Bool
        let grams: Double
        var id: Date { date }
    }

    struct DailyGrams: Identifiable {
        let date: Date
        let grams: Double
        var id: Date { date }
    }

    struct WeeklyCompliance {
        let taken: Int
        let total: Int
        let percentage: Double
    }

    struct HistoryStats {
        let avgPerDay: Double
        let total: Double
        let daysTracked: Int
    }

    static func todayEntries(
        from entries: [CreatineEntry],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [CreatineEntry] {
        let start = calendar.startOfDay(for: now)
        return entries.filter { $0.date >= start }
    }

    static func todayTotalGrams(todayEntries: [CreatineEntry]) -> Double {
        todayEntries.reduce(0) { $0 + $1.grams }
    }

    static func hasTakenToday(todayEntries: [CreatineEntry]) -> Bool {
        !todayEntries.isEmpty
    }

    static func todayComplete(todayTotalGrams: Double, dailyTargetGrams: Double) -> Bool {
        todayTotalGrams >= dailyTargetGrams
    }

    static func dosesRemainingToday(
        isLoadingPhase: Bool,
        loadingDosesPerDay: Int,
        todayEntryCount: Int,
        todayComplete: Bool
    ) -> Int {
        if isLoadingPhase { return max(0, loadingDosesPerDay - todayEntryCount) }
        return todayComplete ? 0 : 1
    }

    static func currentStreak(
        entries: [CreatineEntry],
        hasTakenToday: Bool,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        var streak = 0
        var checkDate = calendar.startOfDay(for: now)
        if !hasTakenToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while true {
            let dayStart = checkDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            if entries.contains(where: { $0.date >= dayStart && $0.date < dayEnd }) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else { break }
        }
        return streak
    }

    static func longestStreak(entries: [CreatineEntry], calendar: Calendar = .current) -> Int {
        let sortedDates = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard !sortedDates.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) } else { current = 1 }
        }
        return longest
    }

    static func weeklyCompliance(
        entries: [CreatineEntry],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> WeeklyCompliance {
        let today = calendar.startOfDay(for: now)
        var taken = 0
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: date) else { continue }
            if entries.contains(where: { $0.date >= date && $0.date < dayEnd }) { taken += 1 }
        }
        let pct = Double(taken) / 7.0 * 100
        return WeeklyCompliance(taken: taken, total: 7, percentage: pct)
    }

    static func lastNDayStatus(
        entries: [CreatineEntry],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DayStatus] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset -> DayStatus? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let dayEntries = entries.filter { $0.date >= date && $0.date < nextDay }
            let grams = dayEntries.reduce(0) { $0 + $1.grams }
            return DayStatus(date: date, taken: !dayEntries.isEmpty, grams: grams)
        }
    }

    static func dailyGrams(
        entries: [CreatineEntry],
        days: Int,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [DailyGrams] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset -> DailyGrams? in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let grams = entries.filter { $0.date >= date && $0.date < nextDay }.reduce(0) { $0 + $1.grams }
            return DailyGrams(date: date, grams: grams)
        }
    }

    static func historyStats(for daily: [DailyGrams]) -> HistoryStats {
        let daysWithData = daily.filter { $0.grams > 0 }.count
        let total = daily.reduce(0) { $0 + $1.grams }
        let avg = daysWithData > 0 ? total / Double(daysWithData) : 0
        return HistoryStats(avgPerDay: avg, total: total, daysTracked: daysWithData)
    }
}
