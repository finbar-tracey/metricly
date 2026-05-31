import Foundation

enum ReportPeriod: String, CaseIterable {
    case week = "This Week"
    case month = "This Month"
}

/// Aggregated training / cardio / body metrics for a report period.
struct WeeklyMonthlyReportSnapshot {
    let period: ReportPeriod
    let periodLabel: String
    let vibeEmoji: String

    let currentRange: (start: Date, end: Date)
    let previousRange: (start: Date, end: Date)

    let workoutCount: Int
    let totalSets: Int
    let totalVolumeKg: Double
    let totalDuration: TimeInterval
    let formattedDuration: String
    let volumeChange: Double?

    let prExerciseNames: [String]
    let prsHitCount: Int
    let muscleGroupSetCounts: [(group: MuscleGroup, sets: Int)]

    let periodBodyWeightEntries: [BodyWeightEntry]
    let bodyWeightStart: Double?
    let bodyWeightEnd: Double?
    let bodyWeightChange: Double?

    let currentStreak: Int
    let workoutsPerWeekAverage: Double?
    let bestDay: String?

    let periodCardioSessions: [CardioSession]
    let cardioCount: Int
    let cardioDistanceKm: Double
    let cardioDuration: TimeInterval
    let formattedCardioDuration: String
    let cardioZoneBreakdown: [(zone: HRZone, seconds: Double)]

    var periodWorkoutsEmpty: Bool { workoutCount == 0 }
}

enum WeeklyMonthlyReportEngine {
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f
    }()
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f
    }()
    private static let weekdaySymbols: [String] = DateFormatter().weekdaySymbols ?? []

    struct Inputs {
        var period: ReportPeriod
        var allWorkouts: [Workout]
        var cardioSessions: [CardioSession]
        var bodyWeightEntries: [BodyWeightEntry]
        var resolvedMaxHR: Double = 190
        var referenceDate: Date = .now
    }

    static func make(_ inputs: Inputs) -> WeeklyMonthlyReportSnapshot {
        let calendar = Calendar.current
        let now = inputs.referenceDate

        let currentRange = periodRange(period: inputs.period, calendar: calendar, now: now)
        let previousRange = previousPeriodRange(period: inputs.period, currentStart: currentRange.start, calendar: calendar)

        let periodWorkouts = inputs.allWorkouts.filter { $0.date >= currentRange.start && $0.date <= currentRange.end }
        let previousPeriodWorkouts = inputs.allWorkouts.filter { $0.date >= previousRange.start && $0.date < previousRange.end }
        let workoutsBeforePeriod = inputs.allWorkouts.filter { $0.date < currentRange.start }

        let workoutCount = periodWorkouts.count
        let totalSets = periodWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp && !$0.isCardio }.count }
        }
        let totalVolumeKg = periodWorkouts.reduce(0.0) { $0 + $1.totalVolumeKg() }
        let totalDuration = periodWorkouts.reduce(0) { $0 + ($1.duration ?? 0) }
        let formattedDuration = formatDuration(totalDuration)

        let volumeChange: Double? = {
            let prevVolumeKg = previousPeriodWorkouts.reduce(0.0) { $0 + $1.totalVolumeKg() }
            guard prevVolumeKg > 0 else { return nil }
            return ((totalVolumeKg - prevVolumeKg) / prevVolumeKg) * 100
        }()

        let prExerciseNames = personalRecordNames(period: periodWorkouts, before: workoutsBeforePeriod)
        let prsHitCount = prExerciseNames.count

        let muscleGroupSetCounts = muscleGroupCounts(from: periodWorkouts)

        let periodBodyWeightEntries = inputs.bodyWeightEntries
            .filter { $0.date >= currentRange.start && $0.date <= currentRange.end }
            .sorted { $0.date < $1.date }
        let bodyWeightStart = periodBodyWeightEntries.first?.weight
        let bodyWeightEnd = periodBodyWeightEntries.last?.weight
        let bodyWeightChange: Double? = {
            guard let start = bodyWeightStart, let end = bodyWeightEnd,
                  periodBodyWeightEntries.count >= 2 else { return nil }
            let diff = end - start
            guard abs(diff) > 0.01 else { return nil }
            return diff
        }()

        let currentStreak = Workout.currentStreak(from: inputs.allWorkouts, cardioSessions: inputs.cardioSessions)

        let workoutsPerWeekAverage: Double? = {
            guard inputs.period == .month, !periodWorkouts.isEmpty else { return nil }
            let daysPassed = max(1, calendar.dateComponents([.day], from: currentRange.start, to: currentRange.end).day ?? 1)
            return Double(periodWorkouts.count) / max(1.0, Double(daysPassed) / 7.0)
        }()

        let bestDay: String? = {
            guard !periodWorkouts.isEmpty else { return nil }
            var dayCounts: [Int: Int] = [:]
            for workout in periodWorkouts {
                dayCounts[calendar.component(.weekday, from: workout.date), default: 0] += 1
            }
            guard let bestWeekday = dayCounts.max(by: { $0.value < $1.value })?.key else { return nil }
            return weekdaySymbols[bestWeekday - 1]
        }()

        let periodLabel = label(for: inputs.period, range: currentRange, calendar: calendar, now: now)

        let vibeEmoji = vibe(
            periodWorkouts: periodWorkouts,
            prsHitCount: prsHitCount,
            rangeStart: currentRange.start,
            now: now,
            calendar: calendar
        )

        let periodCardioSessions = inputs.cardioSessions.filter { $0.date >= currentRange.start && $0.date < currentRange.end }
        let cardioCount = periodCardioSessions.count
        let cardioDistanceKm = periodCardioSessions.reduce(0) { $0 + $1.distanceMeters } / 1000
        let cardioDuration = periodCardioSessions.reduce(0) { $0 + $1.durationSeconds }
        let formattedCardioDuration = formatDuration(cardioDuration)
        let cardioZoneBreakdown = zoneBreakdown(sessions: periodCardioSessions, maxHR: inputs.resolvedMaxHR)

        return WeeklyMonthlyReportSnapshot(
            period: inputs.period,
            periodLabel: periodLabel,
            vibeEmoji: vibeEmoji,
            currentRange: currentRange,
            previousRange: previousRange,
            workoutCount: workoutCount,
            totalSets: totalSets,
            totalVolumeKg: totalVolumeKg,
            totalDuration: totalDuration,
            formattedDuration: formattedDuration,
            volumeChange: volumeChange,
            prExerciseNames: prExerciseNames,
            prsHitCount: prsHitCount,
            muscleGroupSetCounts: muscleGroupSetCounts,
            periodBodyWeightEntries: periodBodyWeightEntries,
            bodyWeightStart: bodyWeightStart,
            bodyWeightEnd: bodyWeightEnd,
            bodyWeightChange: bodyWeightChange,
            currentStreak: currentStreak,
            workoutsPerWeekAverage: workoutsPerWeekAverage,
            bestDay: bestDay,
            periodCardioSessions: periodCardioSessions,
            cardioCount: cardioCount,
            cardioDistanceKm: cardioDistanceKm,
            cardioDuration: cardioDuration,
            formattedCardioDuration: formattedCardioDuration,
            cardioZoneBreakdown: cardioZoneBreakdown
        )
    }

    // MARK: - Period boundaries

    static func periodRange(period: ReportPeriod, calendar: Calendar = .current, now: Date = .now) -> (start: Date, end: Date) {
        switch period {
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start, now)
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start, now)
        }
    }

    static func previousPeriodRange(
        period: ReportPeriod,
        currentStart: Date,
        calendar: Calendar = .current
    ) -> (start: Date, end: Date) {
        switch period {
        case .week:
            let prev = calendar.date(byAdding: .day, value: -7, to: currentStart) ?? currentStart
            return (prev, currentStart)
        case .month:
            let prev = calendar.date(byAdding: .month, value: -1, to: currentStart) ?? currentStart
            return (prev, currentStart)
        }
    }

    // MARK: - Private helpers

    private static func formatDuration(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private static func label(for period: ReportPeriod, range: (start: Date, end: Date), calendar: Calendar, now: Date) -> String {
        switch period {
        case .week:
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: range.start) ?? range.end
            return "\(shortDateFormatter.string(from: range.start)) – \(shortDateFormatter.string(from: min(endOfWeek, now)))"
        case .month:
            return monthYearFormatter.string(from: range.start)
        }
    }

    private static func vibe(
        periodWorkouts: [Workout],
        prsHitCount: Int,
        rangeStart: Date,
        now: Date,
        calendar: Calendar
    ) -> String {
        if periodWorkouts.isEmpty { return "😴" }
        let daysPassed = max(1, calendar.dateComponents([.day], from: rangeStart, to: now).day ?? 1)
        let frequency = Double(periodWorkouts.count) / Double(daysPassed) * 7.0
        if prsHitCount >= 3 && frequency >= 4 { return "🔥" }
        if prsHitCount >= 1 && frequency >= 3 { return "💪" }
        if frequency >= 3 { return "✅" }
        if frequency >= 1 { return "👍" }
        return "🌱"
    }

    private static func personalRecordNames(period: [Workout], before: [Workout]) -> [String] {
        var historicalMax: [String: Double] = [:]
        for workout in before {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                let key = exercise.name.lowercased()
                historicalMax[key] = Swift.max(historicalMax[key] ?? 0, maxWeight)
            }
        }
        var prNames: [String] = []
        for workout in period {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                let key = exercise.name.lowercased()
                if maxWeight > 0, maxWeight > (historicalMax[key] ?? 0) {
                    prNames.append(exercise.name)
                    historicalMax[key] = maxWeight
                }
            }
        }
        return prNames
    }

    private static func muscleGroupCounts(from workouts: [Workout]) -> [(group: MuscleGroup, sets: Int)] {
        var counts: [MuscleGroup: Int] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                if let group = exercise.category {
                    counts[group, default: 0] += exercise.sets.filter { !$0.isWarmUp }.count
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private static func zoneBreakdown(sessions: [CardioSession], maxHR: Double) -> [(zone: HRZone, seconds: Double)] {
        var totals: [HRZone: Double] = [:]
        for s in sessions {
            for split in s.splits {
                guard let hr = split.avgHeartRate else { continue }
                totals[HRZone.zone(for: hr, maxHR: maxHR), default: 0] += split.durationSeconds
            }
        }
        let order: [HRZone] = [.easy, .aerobic, .tempo, .threshold, .max]
        return order.compactMap { z in
            let sec = totals[z] ?? 0
            return sec > 0 ? (zone: z, seconds: sec) : nil
        }
    }

    static func trendInfo(current: Double, previous: Double?, higherIsBetter: Bool) -> (icon: String, isGood: Bool)? {
        guard let prev = previous, prev > 0 else { return nil }
        let diff = current - prev
        guard abs(diff / prev) > 0.02 else { return nil }
        let goingUp = diff > 0
        let isGood = goingUp == higherIsBetter
        return (goingUp ? "arrow.up.right" : "arrow.down.right", isGood)
    }
}
