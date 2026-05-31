import HealthKit
import SwiftUI

// MARK: - Sleep Stage Type

struct SleepStage: Identifiable {
    let id = UUID()
    let type: StageType
    let start: Date
    let end: Date

    enum StageType: String {
        case core = "Core"
        case deep = "Deep"
        case rem = "REM"
        case awake = "Awake"
        case unspecified = "Asleep"

        var color: Color {
            switch self {
            case .deep: return .indigo
            case .core: return .blue
            case .rem: return .cyan
            case .awake: return .orange
            case .unspecified: return .blue
            }
        }
    }

    var durationMinutes: Double {
        end.timeIntervalSince(start) / 60
    }
}

struct DailySleepDetail {
    let date: Date
    let totalMinutes: Double
    let inBed: Date?
    let wakeUp: Date?
    let stages: [SleepStage]
}

// MARK: - Sleep interval merge

enum HealthKitSleepIntervalMerge {
    /// Merges overlapping time intervals and returns the total non-overlapping duration in seconds.
    static func mergedDuration(of intervals: [(start: Date, end: Date)]) -> TimeInterval {
        guard !intervals.isEmpty else { return 0 }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [(start: Date, end: Date)] = [sorted[0]]

        for interval in sorted.dropFirst() {
            if interval.start <= merged[merged.count - 1].end {
                merged[merged.count - 1].end = max(merged[merged.count - 1].end, interval.end)
            } else {
                merged.append(interval)
            }
        }

        return merged.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }
    }
}

// MARK: - Calendar convenience

extension Calendar {
    /// Returns the `.day` DateInterval for a given date. Falls back to a 24-hour interval when
    /// the calendar cannot produce one (virtually impossible for `.day`, but avoids a force-unwrap).
    func healthKitDayInterval(for date: Date) -> DateInterval {
        dateInterval(of: .day, for: date) ?? DateInterval(start: startOfDay(for: date), duration: 86400)
    }

    /// `date(byAdding:)` with a safe fallback to the base date on failure.
    func healthKitAdding(_ component: Component, value: Int, to base: Date) -> Date {
        date(byAdding: component, value: value, to: base) ?? base
    }
}
