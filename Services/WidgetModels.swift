import Foundation

// Shared widget-data models compiled into BOTH the tracker (iPhone) and
// MetriclyWidgetsExtension targets. Before this file existed, each of:
//
//   • Services/WidgetDataWriter.swift  (main app, writer)
//   • MetriclyWidgets/MetriclyWidgets.swift  (widget reader)
//   • MetriclyWidgets/NewWidgets.swift  (widget reader)
//
// kept its own duplicate of these structs. Adding a field meant editing
// three files in lockstep — and at one point the widget's app-group
// suite drifted from the main app's, leaving caffeine + water widgets
// silently empty. One source of truth makes that class of bug harder.
//
// Keep this file Foundation-only (no SwiftUI, no SwiftData). Both
// targets need to compile it.

// MARK: - Stale-data threshold (shared)

enum WidgetStaleness {
    /// Snapshots older than this are considered stale. Widgets render a
    /// dot to signal that the main app hasn't foregrounded recently and
    /// the displayed value may lag reality.
    static let threshold: TimeInterval = 12 * 3600
}

// MARK: - Main app snapshot (workout / streak / cardio)

struct WidgetSnapshot: Codable {
    var streakDays: Int            = 0
    var todayWorkoutName: String   = ""
    var weeklyCardioKm: Double     = 0
    var lastRunPace: String        = ""
    var lastRunDist: String        = ""
    var weeklyGoal: Int            = 0
    var workoutsThisWeek: Int      = 0
    var weeklyCardioGoalKm: Double = 0
    var todayScheduledName: String = ""
    /// Optional — snapshots written before this field existed decode
    /// with nil and won't flag as stale (we just don't know).
    var lastUpdatedAt: Date?       = nil

    var isStale: Bool {
        guard let updatedAt = lastUpdatedAt else { return false }
        return Date.now.timeIntervalSince(updatedAt) > WidgetStaleness.threshold
    }
}

// MARK: - Caffeine snapshot

struct CaffeineWidgetData: Codable {
    struct Entry: Codable {
        var date: Date
        var milligrams: Double
    }
    var entries: [Entry] = []        // last 12 h of logs
    var halfLifeHours: Double = 5.0
    var dailyLimitMg: Double  = 400
    var lastUpdatedAt: Date?  = nil

    var isStale: Bool {
        guard let updatedAt = lastUpdatedAt else { return false }
        return Date.now.timeIntervalSince(updatedAt) > WidgetStaleness.threshold
    }

    /// Remaining caffeine (mg) at the given moment, summed across all
    /// entries using exponential half-life decay.
    func remainingMg(at time: Date = .now) -> Double {
        entries.reduce(0.0) { sum, e in
            let elapsed = max(0, time.timeIntervalSince(e.date))
            return sum + e.milligrams * pow(0.5, elapsed / (halfLifeHours * 3600))
        }
    }

    /// Estimated date when total caffeine drops below 10 mg (effectively
    /// "clear"). Returns nil when already below threshold.
    var clearDate: Date? {
        let total = remainingMg()
        guard total > 10 else { return nil }
        // total × 0.5^(t / hl) = 10  →  t = hl × log2(total / 10)
        let t = halfLifeHours * 3600 * log2(total / 10)
        return Date().addingTimeInterval(t)
    }
}

// MARK: - Water snapshot

struct WaterWidgetData: Codable {
    var todayMl: Double = 0
    var goalMl: Double  = 2500
    var lastUpdatedAt: Date? = nil

    var progress: Double { goalMl > 0 ? min(1, todayMl / goalMl) : 0 }
    var isComplete: Bool { todayMl >= goalMl }

    var isStale: Bool {
        guard let updatedAt = lastUpdatedAt else { return false }
        return Date.now.timeIntervalSince(updatedAt) > WidgetStaleness.threshold
    }

    var formattedToday: String {
        todayMl >= 1000
            ? String(format: "%.1fL", todayMl / 1000)
            : String(format: "%.0f ml", todayMl)
    }
    var formattedGoal: String {
        goalMl >= 1000
            ? String(format: "%.1fL", goalMl / 1000)
            : String(format: "%.0f ml", goalMl)
    }
}

// MARK: - App Group suite identifier (single source of truth)

/// Application-group identifier shared by every entitlements file. Both
/// the main app's writer and the widget extension's readers must point
/// here — the wrong suite gives you a silently-empty isolated
/// UserDefaults instead of the actual shared one.
enum WidgetAppGroup {
    static let suiteName = "group.com.Finbar.FinApp"
}
