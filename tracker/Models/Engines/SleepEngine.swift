import Foundation

/// Pure sleep score, debt, and trend math.
enum SleepEngine {

    static let targetMinutesPerNight: Double = 480

    static func sleepScore(
        todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]),
        detailedSleep: [DailySleepDetail]
    ) -> Int {
        let duration = durationScore(minutes: todaySleep.totalMinutes)
        let stages = stageQualityScore(stages: todaySleep.stages)
        let consistency = consistencyScore(detailedSleep: detailedSleep)
        let efficiency = efficiencyScore(
            totalMinutes: todaySleep.totalMinutes,
            inBed: todaySleep.inBed,
            wakeUp: todaySleep.wakeUp
        )
        return min(100, max(0, duration + stages + consistency + efficiency))
    }

    static func sleepScoreLabel(score: Int) -> String {
        if score >= 85 { return "Excellent" }
        if score >= 70 { return "Good" }
        if score >= 50 { return "Fair" }
        return "Poor"
    }

    static func sleepEfficiency(
        totalMinutes: Double,
        inBed: Date?,
        wakeUp: Date?
    ) -> Double? {
        guard let inBed, let wakeUp else { return nil }
        let timeInBed = wakeUp.timeIntervalSince(inBed) / 60
        guard timeInBed > 0 else { return nil }
        return (totalMinutes / timeInBed) * 100
    }

    static func averageSleep(dailySleep: [(date: Date, minutes: Double)]) -> Double {
        guard !dailySleep.isEmpty else { return 0 }
        return dailySleep.map(\.minutes).reduce(0, +) / Double(dailySleep.count)
    }

    static func chartSleep(
        dailySleep: [(date: Date, minutes: Double)],
        dayCount: Int
    ) -> [(date: Date, minutes: Double)] {
        Array(dailySleep.suffix(dayCount))
    }

    static func thisWeekAverage(dailySleep: [(date: Date, minutes: Double)], now: Date = .now) -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeek = dailySleep.filter { $0.date >= weekStart }
        guard !thisWeek.isEmpty else { return 0 }
        return thisWeek.map(\.minutes).reduce(0, +) / Double(thisWeek.count)
    }

    static func lastWeekAverage(dailySleep: [(date: Date, minutes: Double)], now: Date = .now) -> Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let lastWeek = dailySleep.filter { $0.date >= prevStart && $0.date < weekStart }
        guard !lastWeek.isEmpty else { return 0 }
        return lastWeek.map(\.minutes).reduce(0, +) / Double(lastWeek.count)
    }

    static func accumulatedDebtHours(
        detailedSleep: [DailySleepDetail],
        targetMinutes: Double = targetMinutesPerNight
    ) -> Double {
        let totalDebt = detailedSleep.reduce(0.0) { debt, day in
            debt + max(0, targetMinutes - day.totalMinutes)
        }
        return totalDebt / 60
    }

    static func shiftedMinutes(_ date: Date, calendar: Calendar = .current) -> Double {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let total = Double(hour * 60 + minute)
        return total >= 1080 ? total - 1080 : total + 360
    }

    static func formatShiftedMinutes(_ shifted: Double) -> String {
        let actual = shifted >= 360 ? shifted - 360 : shifted + 1080
        let totalMins = Int(actual) % 1440
        let hour = totalMins / 60
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(displayHour) \(ampm)"
    }

    // MARK: - Score components

    private static func durationScore(minutes: Double) -> Int {
        if minutes >= 420 && minutes <= 540 { return 25 }
        if minutes >= 360 && minutes < 420 { return Int(15 + (minutes - 360) / 60 * 10) }
        if minutes >= 300 && minutes < 360 { return Int(5 + (minutes - 300) / 60 * 10) }
        if minutes < 300 { return Int(max(0, minutes / 300 * 5)) }
        if minutes > 540 && minutes <= 600 { return 20 }
        return 15
    }

    private static func stageQualityScore(stages: [SleepStage]) -> Int {
        guard !stages.isEmpty else { return 15 }
        let totalSleep = stages.filter { $0.type != .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        guard totalSleep > 0 else { return 15 }
        let deepMins = stages.filter { $0.type == .deep }.reduce(0.0) { $0 + $1.durationMinutes }
        let remMins = stages.filter { $0.type == .rem }.reduce(0.0) { $0 + $1.durationMinutes }
        let awakeMins = stages.filter { $0.type == .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        let totalAll = totalSleep + awakeMins
        let deepPct = deepMins / totalSleep * 100
        let remPct = remMins / totalSleep * 100
        let awakePct = totalAll > 0 ? awakeMins / totalAll * 100 : 0
        var deepScore: Double = 10
        if deepPct < 15 { deepScore = max(0, deepPct / 15 * 10) }
        else if deepPct > 20 { deepScore = max(4, 10 - (deepPct - 20) / 10 * 6) }
        var remScore: Double = 10
        if remPct < 20 { remScore = max(0, remPct / 20 * 10) }
        else if remPct > 25 { remScore = max(4, 10 - (remPct - 25) / 10 * 6) }
        var awakeScore: Double = 5
        if awakePct > 5 { awakeScore = max(0, 5 - (awakePct - 5) / 10 * 5) }
        return Int(deepScore + remScore + awakeScore)
    }

    private static func consistencyScore(detailedSleep: [DailySleepDetail]) -> Int {
        let withTimes = detailedSleep.filter { $0.inBed != nil && $0.wakeUp != nil }
        guard withTimes.count >= 3 else { return 15 }
        let calendar = Calendar.current
        let bedMinutes = withTimes.compactMap { detail -> Double? in
            guard let bed = detail.inBed else { return nil }
            let h = calendar.component(.hour, from: bed)
            let m = calendar.component(.minute, from: bed)
            let total = Double(h * 60 + m)
            return total >= 1080 ? total - 1080 : total + 360
        }
        let wakeMinutes = withTimes.compactMap { detail -> Double? in
            guard let wake = detail.wakeUp else { return nil }
            let h = calendar.component(.hour, from: wake)
            let m = calendar.component(.minute, from: wake)
            let total = Double(h * 60 + m)
            return total >= 1080 ? total - 1080 : total + 360
        }
        let bedStdDev = standardDeviation(bedMinutes)
        let wakeStdDev = standardDeviation(wakeMinutes)
        let avgDev = (bedStdDev + wakeStdDev) / 2
        if avgDev <= 30 { return 25 }
        if avgDev <= 60 { return Int(15 + (60 - avgDev) / 30 * 10) }
        if avgDev <= 90 { return Int(5 + (90 - avgDev) / 30 * 10) }
        return Int(max(0, 5 - (avgDev - 90) / 30 * 5))
    }

    private static func efficiencyScore(totalMinutes: Double, inBed: Date?, wakeUp: Date?) -> Int {
        guard let eff = sleepEfficiency(totalMinutes: totalMinutes, inBed: inBed, wakeUp: wakeUp) else { return 15 }
        if eff >= 90 { return 25 }
        if eff >= 85 { return 20 }
        if eff >= 80 { return 15 }
        if eff >= 75 { return 10 }
        return Int(max(0, eff / 75 * 10))
    }

    private static func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }
}
