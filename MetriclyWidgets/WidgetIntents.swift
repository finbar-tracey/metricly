import AppIntents
import WidgetKit

// MARK: - Log Water from Widget

/// Appends a pending water entry (250 ml) to the App Group UserDefaults.
/// The main app processes pending entries in WaterTrackerView.onAppear.
struct LogWaterFromWidgetIntent: AppIntent {
    static var title: LocalizedStringResource = "Log 250 ml Water"
    static var description = IntentDescription("Adds 250 ml to today's water intake from the home screen widget.")

    private static let suite   = "group.com.Finbar.FinApp"
    private static let pendingKey = "pendingWaterMl"

    func perform() async throws -> some IntentResult {
        guard let defaults = UserDefaults(suiteName: Self.suite) else {
            return .result()
        }
        // Accumulate pending ml — main app drains on next foreground
        let existing = defaults.double(forKey: Self.pendingKey)
        defaults.set(existing + 250, forKey: Self.pendingKey)

        // Optimistically bump the widget snapshot so the ring updates immediately
        if let raw  = defaults.data(forKey: "waterWidgetData"),
           var snap = try? JSONDecoder().decode(WaterWidgetData.self, from: raw) {
            snap = WaterWidgetData(todayMl: snap.todayMl + 250, goalMl: snap.goalMl)
            if let updated = try? JSONEncoder().encode(snap) {
                defaults.set(updated, forKey: "waterWidgetData")
            }
        }

        WidgetCenter.shared.reloadTimelines(ofKind: "WaterWidget")
        WidgetCenter.shared.reloadTimelines(ofKind: "WeeklyRingsWidget")
        return .result()
    }
}
