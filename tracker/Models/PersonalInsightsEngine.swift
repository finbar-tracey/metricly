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
        var bodyWeights: [BodyWeightEntry] = []
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
        if let i = bodyWeightVsStrength(inputs)  { insights.append(i) }
        if let i = timeOfDayVsPerformance(inputs) { insights.append(i) }
        if let i = trainingFrequencyTrend(inputs) { insights.append(i) }
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

    // MARK: - Insight: Body weight × strength

    /// Compare top working-set weight on the user's most-frequent compound
    /// lift between days when their body weight is above and below their
    /// 60-day average. Surfaces "do you lift better when you're heavier?"
    static func bodyWeightVsStrength(_ inputs: Inputs) -> Insight? {
        guard inputs.bodyWeights.count >= 6 else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let workouts = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }
        guard workouts.count >= 6 else { return nil }

        // Pick the top-frequency exercise across recent workouts
        let allExercises = workouts.flatMap(\.exercises)
        let counts = Dictionary(grouping: allExercises, by: { $0.name.lowercased() })
            .mapValues { $0.count }
        guard let topName = counts.max(by: { $0.value < $1.value })?.key,
              counts[topName, default: 0] >= 6
        else { return nil }

        // Average body weight over the window (in kg)
        let recentWeights = inputs.bodyWeights
            .filter { $0.date >= cutoff }
            .map(\.weight)
        guard recentWeights.count >= 4 else { return nil }
        let avgBW = recentWeights.reduce(0, +) / Double(recentWeights.count)

        // Build (workout date → top-set weight) for the chosen exercise
        let perSession: [(date: Date, topWeight: Double)] = workouts.compactMap { w in
            let sets = w.exercises
                .filter { $0.name.lowercased() == topName }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp && $0.weight > 0 }
            guard let m = sets.map(\.weight).max() else { return nil }
            return (w.date, m)
        }

        // For each session, find the closest body-weight reading within 7 days
        let bwByDay = inputs.bodyWeights.sorted { $0.date < $1.date }
        var heavier: [Double] = []
        var lighter: [Double] = []
        for s in perSession {
            guard let nearest = bwByDay
                .filter({ abs($0.date.timeIntervalSince(s.date)) <= 7 * 24 * 3600 })
                .min(by: { abs($0.date.timeIntervalSince(s.date)) < abs($1.date.timeIntervalSince(s.date)) })
            else { continue }
            if nearest.weight > avgBW { heavier.append(s.topWeight) }
            else if nearest.weight < avgBW { lighter.append(s.topWeight) }
        }
        guard heavier.count >= 3, lighter.count >= 3 else { return nil }

        let avgHeavy = heavier.reduce(0, +) / Double(heavier.count)
        let avgLight = lighter.reduce(0, +) / Double(lighter.count)
        guard avgLight > 0 else { return nil }
        let pct = (avgHeavy - avgLight) / avgLight * 100
        guard abs(pct) >= 4 else { return nil }

        let displayName = workouts
            .flatMap(\.exercises)
            .first { $0.name.lowercased() == topName }?.name ?? topName.capitalized

        let strength: Insight.Strength = {
            if abs(pct) >= 8 && heavier.count + lighter.count >= 12 { return .strong }
            if abs(pct) >= 6 { return .moderate }
            return .weak
        }()
        let direction = pct >= 0 ? "stronger" : "weaker"

        return Insight(
            category: .performance,
            title: "Body weight and your \(displayName.lowercased())",
            message: String(
                format: "When your body weight is above your average, your %@ is about %.0f%% %@.",
                displayName.lowercased(), abs(pct), direction
            ),
            detail: "Based on \(heavier.count + lighter.count) sessions in the last 90 days",
            strength: strength,
            icon: "scalemass.fill",
            weight: 0.7 * Double(heavier.count + lighter.count) + abs(pct)
        )
    }

    // MARK: - Insight: Time of day × performance

    /// Compare top working-set weight on the user's most-frequent lift between
    /// morning, afternoon, and evening sessions. Reports the strongest time
    /// of day if the gap is meaningful.
    static func timeOfDayVsPerformance(_ inputs: Inputs) -> Insight? {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: .now) ?? .distantPast
        let workouts = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }
        guard workouts.count >= 8 else { return nil }

        // Most-frequent compound lift
        let allExercises = workouts.flatMap(\.exercises)
        let counts = Dictionary(grouping: allExercises, by: { $0.name.lowercased() })
            .mapValues { $0.count }
        guard let topName = counts.max(by: { $0.value < $1.value })?.key,
              counts[topName, default: 0] >= 8
        else { return nil }

        // Bucket sessions by time of day
        var morning: [Double] = []     // before 12
        var afternoon: [Double] = []   // 12 – 17
        var evening: [Double] = []     // 17+
        for w in workouts {
            let hour = Calendar.current.component(.hour, from: w.startTime ?? w.date)
            let topSet = w.exercises
                .filter { $0.name.lowercased() == topName }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp && $0.weight > 0 }
                .map(\.weight).max()
            guard let weight = topSet else { continue }

            if hour < 12 { morning.append(weight) }
            else if hour < 17 { afternoon.append(weight) }
            else { evening.append(weight) }
        }

        // Need ≥3 sessions in at least 2 buckets
        let buckets: [(label: String, values: [Double])] = [
            ("morning",   morning),
            ("afternoon", afternoon),
            ("evening",   evening),
        ].filter { $0.values.count >= 3 }
        guard buckets.count >= 2 else { return nil }

        // Find the strongest and weakest by average
        let averaged = buckets.map { (label: $0.label, avg: $0.values.reduce(0, +) / Double($0.values.count), n: $0.values.count) }
        guard let best = averaged.max(by: { $0.avg < $1.avg }),
              let worst = averaged.min(by: { $0.avg < $1.avg }),
              best.label != worst.label,
              worst.avg > 0
        else { return nil }
        let pct = (best.avg - worst.avg) / worst.avg * 100
        guard pct >= 4 else { return nil }

        let displayName = workouts
            .flatMap(\.exercises)
            .first { $0.name.lowercased() == topName }?.name ?? topName.capitalized

        let strength: Insight.Strength = {
            if pct >= 8 && best.n + worst.n >= 10 { return .strong }
            if pct >= 6 { return .moderate }
            return .weak
        }()

        return Insight(
            category: .performance,
            title: "You're strongest in the \(best.label)",
            message: String(
                format: "Your %@ averages %.0f%% more weight in the %@ than in the %@.",
                displayName.lowercased(), pct, best.label, worst.label
            ),
            detail: "Based on \(best.n + worst.n) sessions in the last 90 days",
            strength: strength,
            icon: best.label == "morning" ? "sunrise.fill"
                : best.label == "evening" ? "moon.fill" : "sun.max.fill",
            weight: 0.7 * Double(best.n + worst.n) + pct
        )
    }

    // MARK: - Insight: Training frequency trend

    /// Compare sessions per week in the last 28 days vs the prior 28 days.
    /// Surfaces meaningful changes in training volume.
    static func trainingFrequencyTrend(_ inputs: Inputs) -> Insight? {
        let cal = Calendar.current
        let now = Date.now
        let recentStart  = cal.date(byAdding: .day, value: -28, to: now) ?? .distantPast
        let priorStart   = cal.date(byAdding: .day, value: -56, to: now) ?? .distantPast

        let recent = inputs.workouts.filter { $0.date >= recentStart && $0.endTime != nil }.count
                   + inputs.cardioSessions.filter { $0.date >= recentStart }.count
        let prior = inputs.workouts.filter { $0.date >= priorStart && $0.date < recentStart && $0.endTime != nil }.count
                  + inputs.cardioSessions.filter { $0.date >= priorStart && $0.date < recentStart }.count

        guard prior >= 4 else { return nil }   // Need a baseline
        guard recent >= 4 else { return nil }   // Don't want to scold someone who took a break

        let recentPerWeek = Double(recent) / 4.0
        let priorPerWeek  = Double(prior) / 4.0
        let pct = (recentPerWeek - priorPerWeek) / priorPerWeek * 100
        guard abs(pct) >= 15 else { return nil }   // 15% threshold to avoid noise

        let strength: Insight.Strength = abs(pct) >= 30 ? .moderate : .weak

        let title = pct >= 0 ? "Training more lately" : "Training less lately"
        let direction = pct >= 0 ? "up" : "down"

        return Insight(
            category: .consistency,
            title: title,
            message: String(
                format: "You're averaging %.1f sessions/week — %@ %.0f%% from %.1f the previous month.",
                recentPerWeek, direction, abs(pct), priorPerWeek
            ),
            detail: "\(recent) sessions in last 28 days vs \(prior) the month before",
            strength: strength,
            icon: pct >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill",
            weight: 8 + abs(pct) / 5   // Sits below richer insights but above baseline frequency
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
