import Foundation
import SwiftData

/// Builds the canonical Watch / widget context dictionary from SwiftData.
enum WatchContextBuilder {

    @MainActor
    static func build(from context: ModelContext) -> [String: Any] {
        let settings = (try? context.fetch(FetchDescriptor<UserSettings>()))?.first
        let weekday  = Calendar.current.component(.weekday, from: .now)
        let todayPlanName = settings?.weeklyPlan[weekday] ?? ""
        let useKg = settings?.useKilograms ?? true

        let allExercises = (try? context.fetch(FetchDescriptor<Exercise>(
            sortBy: [SortDescriptor(\.name)]
        ))) ?? []
        let uniqueNames = Array(Set(allExercises.map(\.name))).sorted().prefix(50)

        let workouts = (try? context.fetch(FetchDescriptor<Workout>())) ?? []
        let cardio   = (try? context.fetch(FetchDescriptor<CardioSession>())) ?? []
        let streak   = Workout.currentStreak(from: workouts, cardioSessions: Array(cardio.prefix(60)))

        let plannedExercises: [String] = {
            guard !todayPlanName.isEmpty else { return [] }
            let match = workouts
                .filter { !$0.isTemplate && $0.endTime != nil
                          && $0.name.localizedCaseInsensitiveCompare(todayPlanName) == .orderedSame }
                .max(by: { $0.date < $1.date })
            return match?.exercises.sorted { $0.order < $1.order }.map(\.name) ?? []
        }()

        var perRest: [String: Int] = [:]
        var seenKeys = Set<String>()
        for ex in allExercises.reversed() where ex.customRestDuration != nil {
            let key = ex.name.lowercased()
            guard !seenKeys.contains(key) else { continue }
            seenKeys.insert(key)
            perRest[ex.name] = ex.customRestDuration
        }

        let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName)
        let activeStartedAt = defaults?.double(forKey: "watch.activeStartedAt") ?? 0
        let activeName = defaults?.string(forKey: "watch.activeName") ?? ""
        let restSeconds = settings?.defaultRestDuration ?? 60

        var payload: [String: Any] = [
            WatchMessageKey.exerciseList:    Array(uniqueNames),
            WatchMessageKey.todayPlan:       todayPlanName,
            WatchMessageKey.todayExercises:  plannedExercises,
            WatchMessageKey.useKilograms:    useKg,
            WatchMessageKey.currentStreak:   streak,
            WatchMessageKey.restDuration:    restSeconds,
            WatchMessageKey.activeStartedAt: activeStartedAt,
            WatchMessageKey.activeName:      activeName
        ]
        if !perRest.isEmpty {
            payload[WatchMessageKey.perExerciseRest] = perRest
        }
        if let plan = TodayPlanStore.load() {
            payload[WatchMessageKey.adaptivePlanName] = plan.recommendedName
            payload[WatchMessageKey.adaptiveIntensity] = plan.intensity.rawValue
            payload[WatchMessageKey.adaptiveTopReason] = plan.reasons.first ?? ""
        }

        let blocks = (try? context.fetch(FetchDescriptor<TrainingBlock>())) ?? []
        if let active = TrainingBlockEngine.currentBlock(in: blocks) {
            payload[WatchMessageKey.blockPhase] = active.phase.rawValue
            payload[WatchMessageKey.blockWeekLabel] =
                TrainingBlockEngine.progressLabel(for: active) ?? ""
        } else {
            payload[WatchMessageKey.blockPhase] = ""
            payload[WatchMessageKey.blockWeekLabel] = ""
        }
        return payload
    }
}
