import Foundation
import WidgetKit

/// Writes summaries of current state to the shared App Group UserDefaults so
/// home-screen widgets can read them without a SwiftData context.
///
/// The model types (`WidgetSnapshot`, `CaffeineWidgetData`, `WaterWidgetData`)
/// live in `Services/WidgetModels.swift` and are shared between this writer
/// and the widget extension's readers.
struct WidgetDataWriter {

    /// Re-exported from `WidgetAppGroup` for legacy call sites; the
    /// canonical constant lives next to the shared models.
    static let suiteName = WidgetAppGroup.suiteName

    /// Merge-update the widget snapshot. Pass `nil` (or omit) any field the caller
    /// doesn't have authoritative data for — the existing value is preserved.
    /// Pass an explicit value to overwrite that field.
    static func update(
        streakDays: Int? = nil,
        todayWorkoutName: String? = nil,
        weeklyCardioKm: Double? = nil,
        lastRunPace: String? = nil,
        lastRunDist: String? = nil,
        weeklyGoal: Int? = nil,
        workoutsThisWeek: Int? = nil,
        weeklyCardioGoalKm: Double? = nil,
        todayScheduledName: String? = nil,
        readinessScore: Double? = nil,
        readinessPlanName: String? = nil
    ) {
        var snapshot = readMainSnapshot() ?? WidgetSnapshot()
        if let v = readinessScore     { snapshot.readinessScore = v }
        if let v = readinessPlanName  { snapshot.readinessPlanName = v }
        if let v = streakDays         { snapshot.streakDays = v }
        if let v = todayWorkoutName   { snapshot.todayWorkoutName = v }
        if let v = weeklyCardioKm     { snapshot.weeklyCardioKm = v }
        if let v = lastRunPace        { snapshot.lastRunPace = v }
        if let v = lastRunDist        { snapshot.lastRunDist = v }
        if let v = weeklyGoal         { snapshot.weeklyGoal = v }
        if let v = workoutsThisWeek   { snapshot.workoutsThisWeek = v }
        if let v = weeklyCardioGoalKm { snapshot.weeklyCardioGoalKm = v }
        if let v = todayScheduledName { snapshot.todayScheduledName = v }
        snapshot.lastUpdatedAt = .now
        write(snapshot, forKey: "widgetData")
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func readMainSnapshot() -> WidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: suiteName),
              let data = defaults.data(forKey: "widgetData"),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
        else { return nil }
        return snapshot
    }

    // MARK: - Type re-exports
    //
    // The struct definitions live in WidgetModels.swift (shared with the
    // widget extension target). These typealiases preserve the legacy
    // `WidgetDataWriter.CaffeineWidgetData` / `.WaterWidgetData` /
    // `.WidgetSnapshot` qualifiers used by existing test suites and
    // callers — refactoring those away is not in scope.

    typealias WidgetSnapshot = tracker.WidgetSnapshot
    typealias CaffeineWidgetData = tracker.CaffeineWidgetData
    typealias WaterWidgetData = tracker.WaterWidgetData

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
            dailyLimitMg: dailyLimitMg,
            lastUpdatedAt: .now
        )
        write(data, forKey: "caffeineWidgetData")
        WidgetCenter.shared.reloadTimelines(ofKind: "CaffeineWidget")
    }

    // MARK: - Water snapshot writer
    //
    // Model type lives in WidgetModels.swift.

    static func updateWater(todayMl: Double, goalMl: Double) {
        let data = WaterWidgetData(todayMl: todayMl, goalMl: goalMl, lastUpdatedAt: .now)
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
