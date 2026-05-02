import Foundation
import WidgetKit

/// Writes summaries of current state to the shared App Group UserDefaults so
/// home-screen widgets can read them without a SwiftData context.
///
/// Three separate keys keep data isolated so each widget can update independently:
///   "widgetData"          – workout / streak / cardio (existing)
///   "caffeineWidgetData"  – recent caffeine entries + sensitivity settings
///   "waterWidgetData"     – today's water intake + daily goal
struct WidgetDataWriter {

    static let suiteName = "group.com.Finbar.FinApp"

    // MARK: - Main snapshot (workout / streak / cardio)

    struct WidgetSnapshot: Codable {
        var streakDays: Int          = 0
        var todayWorkoutName: String = ""
        var weeklyCardioKm: Double   = 0
        var lastRunPace: String      = ""
        var lastRunDist: String      = ""
        var weeklyGoal: Int          = 0
        var workoutsThisWeek: Int    = 0
        // Extended fields for new widgets
        var weeklyCardioGoalKm: Double = 0
        var todayScheduledName: String = ""
    }

    static func update(
        streakDays: Int,
        todayWorkoutName: String,
        weeklyCardioKm: Double,
        lastRunPace: String,
        lastRunDist: String,
        weeklyGoal: Int,
        workoutsThisWeek: Int,
        weeklyCardioGoalKm: Double = 0,
        todayScheduledName: String = ""
    ) {
        let snapshot = WidgetSnapshot(
            streakDays: streakDays,
            todayWorkoutName: todayWorkoutName,
            weeklyCardioKm: weeklyCardioKm,
            lastRunPace: lastRunPace,
            lastRunDist: lastRunDist,
            weeklyGoal: weeklyGoal,
            workoutsThisWeek: workoutsThisWeek,
            weeklyCardioGoalKm: weeklyCardioGoalKm,
            todayScheduledName: todayScheduledName
        )
        write(snapshot, forKey: "widgetData")
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Caffeine snapshot

    struct CaffeineWidgetData: Codable {
        struct Entry: Codable {
            var date: Date
            var milligrams: Double
        }
        var entries: [Entry] = []          // last 12 h of logs
        var halfLifeHours: Double = 5.0
        var dailyLimitMg: Double  = 400

        /// Remaining caffeine (mg) at the given moment.
        func remainingMg(at time: Date = .now) -> Double {
            entries.reduce(0.0) { total, e in
                let elapsed = max(0, time.timeIntervalSince(e.date))
                return total + e.milligrams * pow(0.5, elapsed / (halfLifeHours * 3600))
            }
        }

        /// Estimated date when caffeine drops below 10 mg (effectively "clear").
        var clearDate: Date? {
            let total = remainingMg()
            guard total > 10 else { return nil }
            // total × 0.5^(t / hl) = 10  →  t = hl × log2(total / 10)
            let t = halfLifeHours * 3600 * log2(total / 10)
            return Date().addingTimeInterval(t)
        }
    }

    static func updateCaffeine(
        entries: [(date: Date, milligrams: Double)],
        halfLifeHours: Double,
        dailyLimitMg: Double
    ) {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        let recent = entries
            .filter { $0.date >= cutoff }
            .map { CaffeineWidgetData.Entry(date: $0.date, milligrams: $0.milligrams) }
        let data = CaffeineWidgetData(
            entries: recent,
            halfLifeHours: halfLifeHours,
            dailyLimitMg: dailyLimitMg
        )
        write(data, forKey: "caffeineWidgetData")
        WidgetCenter.shared.reloadTimelines(ofKind: "CaffeineWidget")
    }

    // MARK: - Water snapshot

    struct WaterWidgetData: Codable {
        var todayMl: Double = 0
        var goalMl: Double  = 2500

        var progress: Double { goalMl > 0 ? min(1, todayMl / goalMl) : 0 }
        var isComplete: Bool { todayMl >= goalMl }

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

    static func updateWater(todayMl: Double, goalMl: Double) {
        let data = WaterWidgetData(todayMl: todayMl, goalMl: goalMl)
        write(data, forKey: "waterWidgetData")
        WidgetCenter.shared.reloadTimelines(ofKind: "WaterWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyRingsWidget")
    }

    // MARK: - Private helpers

    private static func write<T: Encodable>(_ value: T, forKey key: String) {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }
}
