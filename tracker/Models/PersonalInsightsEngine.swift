import Foundation
import SwiftUI

// MARK: - Output

/// A pattern observed in the user's data, framed as a personal trend rather
/// than a medical claim. Always uses tentative language ("appears", "tends to").
struct Insight: Identifiable, Hashable, Codable {
    let id: UUID

    enum Category: String, CaseIterable, Codable {
        case sleep, recovery, performance, caffeine, cardio, consistency
    }

    /// How much we trust this insight given sample size + effect magnitude.
    enum Strength: String, Codable {
        case weak, moderate, strong
        var label: String {
            switch self {
            case .weak:     return "Early signal"
            case .moderate: return "Likely pattern"
            case .strong:   return "Strong pattern"
            }
        }
    }

    let category: Category
    let title: String
    /// Body text — phrased as a personal observation, not advice.
    let message: String
    /// A short detail line (e.g., "Based on 24 sessions in the last 60 days").
    let detail: String?
    let strength: Strength
    let icon: String        // SF Symbol
    /// Sort key — bigger means more prominently surfaced.
    let weight: Double

    init(
        id: UUID = UUID(),
        category: Category,
        title: String,
        message: String,
        detail: String?,
        strength: Strength,
        icon: String,
        weight: Double
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.message = message
        self.detail = detail
        self.strength = strength
        self.icon = icon
        self.weight = weight
    }
}

// MARK: - Engine

enum PersonalInsightsEngine {

    /// Inputs needed to compute insights. All optional — engine skips insights
    /// it can't compute due to missing data.
    struct Inputs {
        var workouts: [Workout] = []
        var cardioSessions: [CardioSession] = []
        var caffeine: [CaffeineEntry] = []
        var sleepByDay: [(date: Date, minutes: Double)] = []
        var hrvByDay: [(date: Date, ms: Double)] = []
        var rhrByDay: [(date: Date, bpm: Double)] = []
    }

    static func generate(_ inputs: Inputs) -> [Insight] {
        var insights: [Insight] = []

        if let i = sleepVsTopExercise(inputs)   { insights.append(i) }
        if let i = restDaysVsPerformance(inputs) { insights.append(i) }
        if let i = lateCaffeineVsSleep(inputs)   { insights.append(i) }
        if let i = highVolumeVsHRV(inputs)       { insights.append(i) }
        if let i = longRunVsLegs(inputs)         { insights.append(i) }
        if let i = trainingFrequency(inputs)     { insights.append(i) }

        return insights.sorted { $0.weight > $1.weight }
    }

    // MARK: - Insight: Sleep × top exercise

    /// For the user's most-frequent compound lift, compare top-set weight
    /// after good sleep (≥7h) vs short sleep (<6h). Needs both groups present.
    static func sleepVsTopExercise(_ inputs: Inputs) -> Insight? {
        guard !inputs.sleepByDay.isEmpty else { return nil }

        // Find top-frequency exercise across the last 90 days
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let workouts = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }
        let allExercises = workouts.flatMap(\.exercises)
        let counts = Dictionary(grouping: allExercises, by: { $0.name.lowercased() })
            .mapValues { $0.count }
        guard let topName = counts.max(by: { $0.value < $1.value })?.key,
              counts[topName, default: 0] >= 6
        else { return nil }

        // Top working-set weight per session for that exercise
        let perSession: [(date: Date, topWeight: Double)] = workouts.compactMap { w in
            let sets = w.exercises
                .filter { $0.name.lowercased() == topName }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp && $0.weight > 0 }
            guard let max = sets.map(\.weight).max() else { return nil }
            return (w.date, max)
        }
        guard perSession.count >= 6 else { return nil }

        // Bucket by sleep on that calendar night (overnight sleep ending that morning)
        let sleepByDay = dictionaryByDay(inputs.sleepByDay) { ($0.date, $0.minutes) }
        var goodGroup: [Double] = []
        var poorGroup: [Double] = []
        for s in perSession {
            let day = Calendar.current.startOfDay(for: s.date)
            guard let mins = sleepByDay[day] else { continue }
            let h = mins / 60
            if h >= 7      { goodGroup.append(s.topWeight) }
            else if h < 6  { poorGroup.append(s.topWeight) }
        }
        guard goodGroup.count >= 3, poorGroup.count >= 3 else { return nil }

        let avgGood = goodGroup.reduce(0, +) / Double(goodGroup.count)
        let avgPoor = poorGroup.reduce(0, +) / Double(poorGroup.count)
        guard avgPoor > 0 else { return nil }
        let pct = (avgGood - avgPoor) / avgPoor * 100
        guard abs(pct) >= 4 else { return nil }   // skip noise-level differences

        let displayName = workouts
            .flatMap(\.exercises)
            .first { $0.name.lowercased() == topName }?.name ?? topName.capitalized

        let strength: Insight.Strength = {
            if abs(pct) >= 10 && goodGroup.count + poorGroup.count >= 10 { return .strong }
            if abs(pct) >= 6 { return .moderate }
            return .weak
        }()

        let direction = pct >= 0 ? "stronger" : "weaker"
        let title = "Sleep affects your \(displayName.lowercased())"
        let msg = String(
            format: "Your %@ sessions average %.0f%% %@ after 7+ hours of sleep compared to nights under 6 hours.",
            displayName.lowercased(), abs(pct), direction
        )
        let detail = "Based on \(goodGroup.count + poorGroup.count) sessions in the last 90 days"

        return Insight(
            category: .sleep,
            title: title,
            message: msg,
            detail: detail,
            strength: strength,
            icon: "moon.fill",
            weight: 0.9 * Double(goodGroup.count + poorGroup.count) + abs(pct)
        )
    }

    // MARK: - Insight: Rest × performance per muscle group

    /// For each muscle group, compare top-set weight after 0–1 vs 2+ days off
    /// training that group. Picks the strongest pattern across groups.
    static func restDaysVsPerformance(_ inputs: Inputs) -> Insight? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let finished = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }
            .sorted { $0.date < $1.date }
        guard finished.count >= 8 else { return nil }

        struct Sample { let date: Date; let topWeight: Double; let restDays: Int }

        var bestInsight: (group: MuscleGroup, pct: Double, n: Int, msgWeight: Double)?

        for group in MuscleGroup.allCases where group != .cardio && group != .other {
            // Sessions that trained this group
            var sessionsForGroup: [(date: Date, topWeight: Double)] = []
            for w in finished {
                let exercises = w.exercises.filter { $0.category == group }
                let sets = exercises.flatMap(\.sets).filter { !$0.isWarmUp && $0.weight > 0 }
                guard let max = sets.map(\.weight).max() else { continue }
                sessionsForGroup.append((w.date, max))
            }
            guard sessionsForGroup.count >= 4 else { continue }

            var freshGroup: [Double] = []
            var tiredGroup: [Double] = []
            for i in 1..<sessionsForGroup.count {
                let gap = Calendar.current.dateComponents([.day],
                    from: Calendar.current.startOfDay(for: sessionsForGroup[i-1].date),
                    to: Calendar.current.startOfDay(for: sessionsForGroup[i].date)).day ?? 0
                if gap >= 2 { freshGroup.append(sessionsForGroup[i].topWeight) }
                else if gap <= 1 { tiredGroup.append(sessionsForGroup[i].topWeight) }
            }
            guard freshGroup.count >= 2, tiredGroup.count >= 2 else { continue }

            let avgFresh = freshGroup.reduce(0, +) / Double(freshGroup.count)
            let avgTired = tiredGroup.reduce(0, +) / Double(tiredGroup.count)
            guard avgTired > 0 else { continue }
            let pct = (avgFresh - avgTired) / avgTired * 100
            guard abs(pct) >= 4 else { continue }

            let n = freshGroup.count + tiredGroup.count
            let msgWeight = Double(n) * 0.5 + abs(pct)
            if bestInsight == nil || msgWeight > bestInsight!.msgWeight {
                bestInsight = (group, pct, n, msgWeight)
            }
        }

        guard let best = bestInsight else { return nil }

        let strength: Insight.Strength = {
            if abs(best.pct) >= 10 && best.n >= 10 { return .strong }
            if abs(best.pct) >= 6 { return .moderate }
            return .weak
        }()
        let groupLabel = best.group.rawValue.lowercased()
        let direction = best.pct >= 0 ? "stronger" : "weaker"

        return Insight(
            category: .recovery,
            title: "Rest helps your \(groupLabel)",
            message: String(
                format: "Your %@ sessions are %.0f%% %@ after 2+ rest days compared with back-to-back days.",
                groupLabel, abs(best.pct), direction
            ),
            detail: "Based on \(best.n) sessions in the last 90 days",
            strength: strength,
            icon: "bed.double.fill",
            weight: 0.85 * Double(best.n) + abs(best.pct)
        )
    }

    // MARK: - Insight: Late caffeine × sleep duration

    /// Compare sleep duration on nights following caffeine after 3pm vs not.
    static func lateCaffeineVsSleep(_ inputs: Inputs) -> Insight? {
        guard !inputs.caffeine.isEmpty, !inputs.sleepByDay.isEmpty else { return nil }
        let lateHour = 15  // 3pm

        let sleepByDay = dictionaryByDay(inputs.sleepByDay) { ($0.date, $0.minutes) }

        // Group caffeine by day; mark whether any was after the late cutoff
        var lateDays = Set<Date>()
        var caffeineDays = Set<Date>()
        for entry in inputs.caffeine {
            let day = Calendar.current.startOfDay(for: entry.date)
            caffeineDays.insert(day)
            let hour = Calendar.current.component(.hour, from: entry.date)
            if hour >= lateHour { lateDays.insert(day) }
        }

        var lateNights: [Double] = []     // minutes of sleep AFTER days with late caffeine
        var earlyNights: [Double] = []    // sleep AFTER days with caffeine but only before cutoff
        for day in caffeineDays {
            // Sleep that began that evening — record it as the day's value
            guard let mins = sleepByDay[day] else { continue }
            if lateDays.contains(day) { lateNights.append(mins) }
            else { earlyNights.append(mins) }
        }
        guard lateNights.count >= 4, earlyNights.count >= 4 else { return nil }

        let avgLate = lateNights.reduce(0, +) / Double(lateNights.count)
        let avgEarly = earlyNights.reduce(0, +) / Double(earlyNights.count)
        let diffMins = avgLate - avgEarly
        guard abs(diffMins) >= 15 else { return nil }   // 15-minute threshold

        let strength: Insight.Strength = {
            if abs(diffMins) >= 30 && lateNights.count + earlyNights.count >= 14 { return .strong }
            if abs(diffMins) >= 20 { return .moderate }
            return .weak
        }()
        let direction = diffMins < 0 ? "less" : "more"
        let absMin = Int(abs(diffMins).rounded())

        return Insight(
            category: .caffeine,
            title: "Late caffeine and your sleep",
            message: "On days when you have caffeine after 3pm, you sleep about \(absMin) minutes \(direction) than usual.",
            detail: "Based on \(lateNights.count + earlyNights.count) days in your records",
            strength: strength,
            icon: "cup.and.saucer.fill",
            weight: 0.8 * Double(lateNights.count + earlyNights.count) + abs(diffMins)
        )
    }

    // MARK: - Insight: High-volume × next-day HRV

    /// Compare HRV the morning after high-volume vs low-volume training days.
    static func highVolumeVsHRV(_ inputs: Inputs) -> Insight? {
        guard !inputs.hrvByDay.isEmpty else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -60, to: .now) ?? .distantPast
        let workouts = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }
        guard workouts.count >= 8 else { return nil }

        // Total volume per workout day
        let volumeByDay: [Date: Double] = {
            var dict: [Date: Double] = [:]
            for w in workouts {
                let day = Calendar.current.startOfDay(for: w.date)
                let vol = w.exercises.flatMap(\.sets)
                    .filter { !$0.isWarmUp }
                    .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
                dict[day, default: 0] += vol
            }
            return dict
        }()
        guard volumeByDay.count >= 6 else { return nil }
        let volumes = volumeByDay.values.sorted()
        guard let high = volumes.last, let low = volumes.first, high > low else { return nil }
        let median = volumes[volumes.count / 2]

        let hrvByDay = dictionaryByDay(inputs.hrvByDay) { ($0.date, $0.ms) }

        var afterHigh: [Double] = []
        var afterLow: [Double] = []
        for (day, vol) in volumeByDay {
            // Look at HRV the next morning
            guard let next = Calendar.current.date(byAdding: .day, value: 1, to: day) else { continue }
            let nextDay = Calendar.current.startOfDay(for: next)
            guard let hrv = hrvByDay[nextDay] else { continue }
            if vol >= median { afterHigh.append(hrv) }
            else { afterLow.append(hrv) }
        }
        guard afterHigh.count >= 3, afterLow.count >= 3 else { return nil }

        let avgHigh = afterHigh.reduce(0, +) / Double(afterHigh.count)
        let avgLow  = afterLow.reduce(0, +)  / Double(afterLow.count)
        guard avgLow > 0 else { return nil }
        let pct = (avgHigh - avgLow) / avgLow * 100
        guard abs(pct) >= 5 else { return nil }

        let strength: Insight.Strength = {
            if abs(pct) >= 10 && afterHigh.count + afterLow.count >= 10 { return .strong }
            if abs(pct) >= 7 { return .moderate }
            return .weak
        }()
        let direction = pct < 0 ? "lower" : "higher"

        return Insight(
            category: .recovery,
            title: "Heavy days affect HRV",
            message: "Your HRV runs \(Int(abs(pct)))% \(direction) the morning after high-volume sessions compared with lighter days.",
            detail: "Based on \(afterHigh.count + afterLow.count) measured days",
            strength: strength,
            icon: "waveform.path.ecg",
            weight: 0.75 * Double(afterHigh.count + afterLow.count) + abs(pct)
        )
    }

    // MARK: - Insight: Long runs × leg readiness

    /// Long cardio sessions tend to reduce leg readiness over the next 36–48h.
    /// Heuristic: average "days until next leg session" after long vs short cardio.
    static func longRunVsLegs(_ inputs: Inputs) -> Insight? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let runs = inputs.cardioSessions.filter { $0.date >= cutoff }
        guard runs.count >= 4 else { return nil }

        // Long = >= 8 km, short = < 5 km
        let longRuns = runs.filter { $0.distanceMeters >= 8000 }
        let shortRuns = runs.filter { $0.distanceMeters < 5000 && $0.distanceMeters > 1000 }
        guard longRuns.count >= 2, shortRuns.count >= 2 else { return nil }

        // Days until next leg session
        let legSessions = inputs.workouts
            .filter { $0.endTime != nil && $0.exercises.contains { $0.category == .legs } }
            .map(\.date)
            .sorted()
        guard legSessions.count >= 3 else { return nil }

        func daysUntilLegs(after date: Date) -> Int? {
            guard let next = legSessions.first(where: { $0 > date }) else { return nil }
            return Calendar.current.dateComponents([.day],
                from: Calendar.current.startOfDay(for: date),
                to: Calendar.current.startOfDay(for: next)).day
        }

        let longGaps = longRuns.compactMap { daysUntilLegs(after: $0.date) }
        let shortGaps = shortRuns.compactMap { daysUntilLegs(after: $0.date) }
        guard longGaps.count >= 2, shortGaps.count >= 2 else { return nil }

        let avgLong = Double(longGaps.reduce(0, +)) / Double(longGaps.count)
        let avgShort = Double(shortGaps.reduce(0, +)) / Double(shortGaps.count)
        let diff = avgLong - avgShort
        guard diff >= 0.5 else { return nil }   // need at least half a day's gap

        let strength: Insight.Strength = diff >= 1.5 ? .moderate : .weak

        return Insight(
            category: .cardio,
            title: "Long runs nudge your leg sessions",
            message: String(
                format: "After runs of 8 km or more, you tend to wait %.1f days longer before your next leg session.",
                diff
            ),
            detail: "Based on \(longGaps.count + shortGaps.count) cardio sessions",
            strength: strength,
            icon: "figure.run",
            weight: 0.6 * Double(longGaps.count + shortGaps.count) + diff * 5
        )
    }

    // MARK: - Insight: Training frequency

    /// Average sessions per week — a baseline "consistency" insight that
    /// shows up early when there isn't enough data for the others.
    static func trainingFrequency(_ inputs: Inputs) -> Insight? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -28, to: .now) ?? .distantPast
        let sessions = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }.count
                     + inputs.cardioSessions.filter { $0.date >= cutoff }.count
        guard sessions >= 4 else { return nil }
        let perWeek = Double(sessions) / 4.0

        let strength: Insight.Strength = perWeek >= 4 ? .strong : (perWeek >= 2 ? .moderate : .weak)

        return Insight(
            category: .consistency,
            title: "Your training rhythm",
            message: String(format: "You're averaging %.1f sessions per week over the last month — \(rhythmComment(perWeek)).", perWeek),
            detail: "\(sessions) sessions in the last 28 days",
            strength: strength,
            icon: "calendar.badge.checkmark",
            // Keep weight low so this doesn't displace richer insights
            weight: 10 + perWeek
        )
    }

    private static func rhythmComment(_ perWeek: Double) -> String {
        if perWeek >= 5 { return "high frequency" }
        if perWeek >= 3 { return "consistent training" }
        if perWeek >= 2 { return "steady habit" }
        return "building the habit"
    }

    // MARK: - Helpers

    /// Bucket an arbitrary date+value sequence by start-of-day, keeping the
    /// largest value per day (longest sleep, highest HRV, etc.).
    private static func dictionaryByDay<T>(_ source: [T], _ extract: (T) -> (Date, Double)) -> [Date: Double] {
        var dict: [Date: Double] = [:]
        for entry in source {
            let (date, value) = extract(entry)
            let day = Calendar.current.startOfDay(for: date)
            dict[day] = max(dict[day] ?? 0, value)
        }
        return dict
    }
}
