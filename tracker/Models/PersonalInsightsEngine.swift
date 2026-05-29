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
        /// Wall-clock "now" used for all lookback-window computations.
        /// Defaults to `.now`; tests inject a fixed date so cutoffs are
        /// deterministic. Matches the same convention as `RecoveryEngine`
        /// and `TodayPlanEngine`.
        var now: Date = .now
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

    /// For the user's most-frequent compound lift, compare *estimated
    /// 1RM* after good sleep (≥7h) vs short sleep (<6h). Needs both
    /// groups present.
    ///
    /// The v1.5 review flagged a real correctness issue with the older
    /// raw-top-weight comparison: a 100kg × 3 set (e1RM ≈ 110kg) and a
    /// 90kg × 10 set (e1RM ≈ 120kg) are different stimuli, but raw
    /// weight read the first as "heavier". Switching to estimated 1RM
    /// via the Epley formula normalises across rep ranges so the
    /// insight compares like-for-like — even when the user mixes
    /// strength days and hypertrophy days for the same exercise.
    static func sleepVsTopExercise(_ inputs: Inputs) -> Insight? {
        guard !inputs.sleepByDay.isEmpty else { return nil }
        let C = EngineConstants.PersonalInsights.self

        // Find top-frequency exercise across the wide lookback window
        let workouts = finishedWorkouts(in: inputs, withinDays: C.wideLookbackDays)
        guard let topName = topExerciseName(in: workouts, minHits: C.minTopExerciseHits)
        else { return nil }

        // Per-session estimated 1RM for that exercise. `topWeight`
        // stays as the variable name for the smaller diff but now
        // holds the e1RM value, not the raw weight.
        let perSession: [(date: Date, topWeight: Double)] = workouts.compactMap { w in
            let sets = w.exercises
                .filter { $0.name.lowercased() == topName }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp && $0.weight > 0 }
            guard let max = sets.map(estimated1RM(of:)).max() else { return nil }
            return (w.date, max)
        }
        guard perSession.count >= C.minTopExerciseHits else { return nil }

        // Bucket by sleep on that calendar night (overnight sleep ending that morning)
        let sleepByDay = dictionaryByDay(inputs.sleepByDay) { ($0.date, $0.minutes) }
        var goodGroup: [Double] = []
        var poorGroup: [Double] = []
        for s in perSession {
            let day = Calendar.current.startOfDay(for: s.date)
            guard let mins = sleepByDay[day] else { continue }
            let h = mins / 60
            if h >= C.goodSleepHours       { goodGroup.append(s.topWeight) }
            else if h < C.shortSleepHours  { poorGroup.append(s.topWeight) }
        }
        // 3-each is a per-bucket floor below the cross-insight default —
        // we need *both* sleep buckets populated, so doubling up.
        guard goodGroup.count >= 3, poorGroup.count >= 3 else { return nil }

        let avgGood = goodGroup.reduce(0, +) / Double(goodGroup.count)
        let avgPoor = poorGroup.reduce(0, +) / Double(poorGroup.count)
        guard avgPoor > 0 else { return nil }
        let pct = (avgGood - avgPoor) / avgPoor * 100
        guard abs(pct) >= C.minEffectPct else { return nil }   // skip noise-level differences

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
        let C = EngineConstants.PersonalInsights.self
        let finished = finishedWorkouts(in: inputs, withinDays: C.wideLookbackDays)
            .sorted { $0.date < $1.date }
        guard finished.count >= 8 else { return nil }

        struct Sample { let date: Date; let topWeight: Double; let restDays: Int }

        var bestInsight: (group: MuscleGroup, pct: Double, n: Int, msgWeight: Double)?

        for group in MuscleGroup.allCases where group != .cardio && group != .other {
            // Sessions that trained this group. We restrict to the
            // user's MOST-FREQUENT exercise within the group so we
            // compare like-for-like across sessions — the previous
            // shape took the max across *every* exercise in the
            // category, mixing 200 kg squat top sets with 250 kg
            // leg-press top sets and confusing "stronger after rest"
            // with "used a different exercise this session." Falling
            // back to nil when no dominant exercise meets the minimum
            // hit count skips the muscle entirely rather than
            // surfacing a noisy comparison.
            let groupTopName = topExerciseName(
                in: finished.filter { w in
                    w.exercises.contains { $0.category == group }
                },
                minHits: 3
            )
            var sessionsForGroup: [(date: Date, topWeight: Double)] = []
            for w in finished {
                let sets = w.exercises
                    .filter { ex in
                        // Prefer the dominant exercise when we have
                        // one; only fall back to "any exercise in
                        // this group" for muscles where no single
                        // movement dominates (the floor is 3 hits, so
                        // sparse data flows through this fallback).
                        if let groupTopName {
                            return ex.name.lowercased() == groupTopName
                        }
                        return ex.category == group
                    }
                    .flatMap(\.sets)
                    .filter { !$0.isWarmUp && $0.weight > 0 }
                // Estimated 1RM, same rationale as the other strength
                // insights: 100kg×3 and 90kg×10 are different stimuli;
                // e1RM normalises so a rep-scheme change between
                // sessions doesn't masquerade as a strength change.
                guard let max = sets.map(estimated1RM(of:)).max() else { continue }
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
            guard abs(pct) >= C.minEffectPct else { continue }

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

    /// Compare sleep duration on nights following caffeine after the late
    /// cutoff hour vs not.
    static func lateCaffeineVsSleep(_ inputs: Inputs) -> Insight? {
        guard !inputs.caffeine.isEmpty, !inputs.sleepByDay.isEmpty else { return nil }
        let C = EngineConstants.PersonalInsights.self

        let sleepByDay = dictionaryByDay(inputs.sleepByDay) { ($0.date, $0.minutes) }

        // Group caffeine by day; mark whether any was after the late cutoff
        var lateDays = Set<Date>()
        var caffeineDays = Set<Date>()
        for entry in inputs.caffeine {
            let day = Calendar.current.startOfDay(for: entry.date)
            caffeineDays.insert(day)
            let hour = Calendar.current.component(.hour, from: entry.date)
            if hour >= C.lateCaffeineHour { lateDays.insert(day) }
        }

        var lateNights: [Double] = []     // minutes of sleep AFTER days with late caffeine
        var earlyNights: [Double] = []    // sleep AFTER days with caffeine but only before cutoff
        for day in caffeineDays {
            // Sleep that began that evening — record it as the day's value
            guard let mins = sleepByDay[day] else { continue }
            if lateDays.contains(day) { lateNights.append(mins) }
            else { earlyNights.append(mins) }
        }
        guard lateNights.count >= C.minPairedSamples, earlyNights.count >= C.minPairedSamples else { return nil }

        let avgLate = lateNights.reduce(0, +) / Double(lateNights.count)
        let avgEarly = earlyNights.reduce(0, +) / Double(earlyNights.count)
        let diffMins = avgLate - avgEarly
        guard abs(diffMins) >= C.minSleepDeltaMinutes else { return nil }

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
        let C = EngineConstants.PersonalInsights.self
        let workouts = finishedWorkouts(in: inputs, withinDays: C.mediumLookbackDays)
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
        guard abs(pct) >= C.minHRVEffectPct else { return nil }

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
        let C = EngineConstants.PersonalInsights.self
        let cutoff = Calendar.current.date(byAdding: .day, value: -C.wideLookbackDays, to: inputs.now) ?? .distantPast
        let runs = inputs.cardioSessions.filter { $0.date >= cutoff }
        guard runs.count >= C.minPairedSamples else { return nil }

        let longRuns = runs.filter { $0.distanceMeters >= C.longRunMeters }
        let shortRuns = runs.filter { $0.distanceMeters < C.shortRunUpperMeters && $0.distanceMeters > C.shortRunLowerMeters }
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
        guard diff >= C.minLongRunDaysGap else { return nil }

        let strength: Insight.Strength = diff >= 1.5 ? .moderate : .weak

        return Insight(
            category: .cardio,
            title: "Long runs nudge your leg sessions",
            message: String(
                format: "After runs of %.0f km or more, you tend to wait %.1f days longer before your next leg session.",
                C.longRunMeters / 1000, diff
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
        let C = EngineConstants.PersonalInsights.self
        guard inputs.bodyWeights.count >= C.minTopExerciseHits else { return nil }
        let cutoff = Calendar.current.date(byAdding: .day, value: -C.wideLookbackDays, to: inputs.now) ?? .distantPast
        let workouts = finishedWorkouts(in: inputs, withinDays: C.wideLookbackDays)
        guard workouts.count >= C.minTopExerciseHits else { return nil }

        // Pick the top-frequency exercise across recent workouts
        guard let topName = topExerciseName(in: workouts, minHits: C.minTopExerciseHits)
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
            // Estimated 1RM (same reason as sleepVsTopExercise above):
            // raw top weight confused different rep schemes for the
            // same exercise. Comparing e1RM normalises strength
            // expression so the bodyweight correlation is the only
            // independent variable left.
            guard let m = sets.map(estimated1RM(of:)).max() else { return nil }
            return (w.date, m)
        }

        // For each session, find the closest body-weight reading within the proximity window
        let proximityWindow: TimeInterval = Double(C.bodyWeightProximityDays) * 24 * 3600
        let bwByDay = inputs.bodyWeights.sorted { $0.date < $1.date }
        var heavier: [Double] = []
        var lighter: [Double] = []
        for s in perSession {
            guard let nearest = bwByDay
                .filter({ abs($0.date.timeIntervalSince(s.date)) <= proximityWindow })
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
        guard abs(pct) >= C.minEffectPct else { return nil }

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
        let C = EngineConstants.PersonalInsights.self
        let workouts = finishedWorkouts(in: inputs, withinDays: C.wideLookbackDays)
        guard workouts.count >= 8 else { return nil }

        // Most-frequent compound lift
        guard let topName = topExerciseName(in: workouts, minHits: C.minTopExerciseHitsTimeOfDay)
        else { return nil }

        // Bucket sessions by time of day
        var morning: [Double] = []     // before 12
        var afternoon: [Double] = []   // 12 – 17
        var evening: [Double] = []     // 17+
        for w in workouts {
            let hour = Calendar.current.component(.hour, from: w.startTime ?? w.date)
            // Estimated 1RM (Epley) — same rep-scheme normalisation as
            // sleepVsTopExercise / bodyWeightVsStrength. The user
            // might do heavy triples in the morning and 10-rep sets in
            // the evening; raw top weight would read morning as
            // "better" purely by load, hiding the actual performance
            // difference.
            let topSet = w.exercises
                .filter { $0.name.lowercased() == topName }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp && $0.weight > 0 }
                .map(estimated1RM(of:)).max()
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
        guard pct >= C.minEffectPct else { return nil }

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
        let C = EngineConstants.PersonalInsights.self
        let cal = Calendar.current
        let recentStart  = cal.date(byAdding: .day, value: -C.trendWindowDays,      to: inputs.now) ?? .distantPast
        let priorStart   = cal.date(byAdding: .day, value: -C.trendWindowPriorDays, to: inputs.now) ?? .distantPast

        let recent = inputs.workouts.filter { $0.date >= recentStart && $0.endTime != nil }.count
                   + inputs.cardioSessions.filter { $0.date >= recentStart }.count
        let prior = inputs.workouts.filter { $0.date >= priorStart && $0.date < recentStart && $0.endTime != nil }.count
                  + inputs.cardioSessions.filter { $0.date >= priorStart && $0.date < recentStart }.count

        guard prior >= C.minPairedSamples else { return nil }   // Need a baseline
        guard recent >= C.minPairedSamples else { return nil }  // Don't scold someone who took a break

        let recentPerWeek = Double(recent) / 4.0
        let priorPerWeek  = Double(prior) / 4.0
        let pct = (recentPerWeek - priorPerWeek) / priorPerWeek * 100
        guard abs(pct) >= C.minTrendPct else { return nil }

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
        let C = EngineConstants.PersonalInsights.self
        let cutoff = Calendar.current.date(byAdding: .day, value: -C.trendWindowDays, to: inputs.now) ?? .distantPast
        let sessions = inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }.count
                     + inputs.cardioSessions.filter { $0.date >= cutoff }.count
        guard sessions >= C.minPairedSamples else { return nil }
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

    /// Workouts that finished within the last `days` days, anchored at
    /// `inputs.now`. Eight call sites used to re-derive this with
    /// `inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }`
    /// — collapsed here so retuning "what counts as recent" is a single
    /// edit and the time-window logic is testable in isolation.
    private static func finishedWorkouts(in inputs: Inputs, withinDays days: Int) -> [Workout] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: inputs.now)
            ?? .distantPast
        return inputs.workouts.filter { $0.date >= cutoff && $0.endTime != nil }
    }

    /// Most-frequently-trained exercise across the given workouts, as a
    /// lowercased name. Returns nil if the top exercise appears fewer
    /// than `minHits` times — that's the "we don't have enough data to
    /// pick a representative compound lift" early-out three insights
    /// (sleep × lift, body weight × lift, time of day × lift) used to
    /// reimplement independently.
    private static func topExerciseName(in workouts: [Workout], minHits: Int) -> String? {
        let counts = Dictionary(grouping: workouts.flatMap(\.exercises),
                                by: { $0.name.lowercased() })
            .mapValues { $0.count }
        guard let top = counts.max(by: { $0.value < $1.value })?.key,
              counts[top, default: 0] >= minHits
        else { return nil }
        return top
    }

    /// Estimated 1RM via the Epley formula —
    ///   `e1RM = weight × (1 + reps / divisor)`, where the divisor is
    ///   the standard 30 (lives in `EngineConstants.Progression.epleyDivisor`).
    ///
    /// Used by every strength insight that aggregates "top set" across
    /// sessions. Raw top weight read 100kg × 3 (≈ 110kg) as heavier
    /// than 90kg × 10 (≈ 120kg) — but they're different stimuli, and
    /// the second is a stronger expression. The v1.5 review flagged
    /// the noise this introduced; estimated 1RM normalises across
    /// rep ranges so the variable the insight cares about (sleep,
    /// bodyweight, time of day) is the only independent left.
    ///
    /// Defensive at the boundaries: zero weight yields zero, 1-rep
    /// sets short-circuit to the weight itself (Epley's `(1 + 1/30)`
    /// is ~1.033 which would over-credit a true single).
    private static func estimated1RM(of set: ExerciseSet) -> Double {
        guard set.weight > 0 else { return 0 }
        let reps = max(1, set.reps)
        if reps == 1 { return set.weight }
        return set.weight * (1.0 + Double(reps) / EngineConstants.Progression.epleyDivisor)
    }

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
