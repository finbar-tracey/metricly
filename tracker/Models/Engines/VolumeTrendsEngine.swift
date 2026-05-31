import Foundation

struct VolumePoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

/// Weekly / monthly lifting volume aggregates for `VolumeTrendsView`.
enum VolumeTrendsEngine {

    static func volumeData(
        workouts: [Workout],
        period: VolumeTrendPeriod,
        calendar: Calendar = .current
    ) -> [VolumePoint] {
        let grouped: [(Date, Double)]
        switch period {
        case .weekly: grouped = groupByWeek(workouts: workouts, calendar: calendar)
        case .monthly: grouped = groupByMonth(workouts: workouts, calendar: calendar)
        }
        return grouped.map { VolumePoint(date: $0.0, volume: $0.1) }
    }

    static func muscleVolumeByGroup(
        workouts: [Workout],
        lastDays: Int = 30,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [(MuscleGroup, Double)] {
        let cutoff = calendar.date(byAdding: .day, value: -lastDays, to: now) ?? now
        let recent = workouts.filter { $0.date >= cutoff }
        var volumes: [MuscleGroup: Double] = [:]
        for workout in recent {
            for exercise in workout.exercises {
                guard let group = exercise.category else { continue }
                let vol = exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
                volumes[group, default: 0] += vol
            }
        }
        return MuscleGroup.allCases
            .filter { $0 != .cardio && $0 != .other }
            .compactMap { group in
                guard let vol = volumes[group], vol > 0 else { return nil }
                return (group, vol)
            }
            .sorted { $0.1 > $1.1 }
    }

    static func totalVolumeThisWeek(
        workouts: [Workout],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return volumeKg(in: workouts, from: startOfWeek)
    }

    static func totalVolumeLastWeek(
        workouts: [Workout],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Double {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: startOfWeek) else { return 0 }
        return volumeKg(in: workouts, from: lastWeekStart, until: startOfWeek)
    }

    /// Week-over-week percent change; mirrors `WeeklyMonthlyReportEngine` volume delta when prior week > 0.
    static func volumeChangePercent(thisWeek: Double, lastWeek: Double) -> Double {
        guard lastWeek > 0 else { return 0 }
        return ((thisWeek - lastWeek) / lastWeek) * 100
    }

    static func workoutsThisWeek(
        workouts: [Workout],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        return workouts.filter { $0.date >= startOfWeek }.count
    }

    static func formatVolume(_ volumeKg: Double, unit: WeightUnit) -> String {
        let displayed = unit.display(volumeKg)
        if displayed >= 1000 { return String(format: "%.1fk %@", displayed / 1000, unit.label) }
        return "\(Int(displayed)) \(unit.label)"
    }

    private static func volumeKg(in workouts: [Workout], from start: Date, until end: Date? = nil) -> Double {
        workouts
            .filter { workout in
                workout.date >= start && (end.map { workout.date < $0 } ?? true)
            }
            .reduce(0.0) { $0 + $1.totalVolumeKg() }
    }

    private static func groupByWeek(workouts: [Workout], calendar: Calendar) -> [(Date, Double)] {
        var weeks: [Date: Double] = [:]
        for workout in workouts {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start else { continue }
            weeks[weekStart, default: 0] += workout.totalVolumeKg()
        }
        return weeks.sorted { $0.key < $1.key }
    }

    private static func groupByMonth(workouts: [Workout], calendar: Calendar) -> [(Date, Double)] {
        var months: [Date: Double] = [:]
        for workout in workouts {
            guard let monthStart = calendar.dateInterval(of: .month, for: workout.date)?.start else { continue }
            months[monthStart, default: 0] += workout.totalVolumeKg()
        }
        return months.sorted { $0.key < $1.key }
    }
}
