import SwiftUI
import SwiftData

/// Home layout and HealthKit state — no SwiftData `@Query` (data from `HomeDashboardStore.snapshot`).
struct HomeDashboardScreen: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.appServices) var appServices
    @Environment(\.weightUnit) var weightUnit
    @Bindable var store: HomeDashboardStore

    let onRefreshSnapshot: () -> Void
    let onRecompute: (HealthSignals, [ExternalWorkout]) -> Void
    let onBuildProgression: (Binding<[HomeProgressionSuggestion]>) -> Void
    let onQuickStart: () -> Void
    let onRepeatLast: () -> Void

    @State var todaySteps: Double = 0
    @State var restingHR: Double?
    @State var sleepMinutes: Double = 0
    @State var hrv: Double?
    @State var averageHRV: Double?
    @State var activeCalories: Double = 0
    @State var averageRestingHR: Double?
    @State var healthDataLoaded = false
    @State var externalWorkouts: [ExternalWorkout] = []
    @State var animateRings = false
    @State var showingAddWorkout = false
    @State var blockForDetailSheet: TrainingBlock?
    @State var homeRoute: HomeRoute?
    @State var topInsight: Insight?
    @State var repeatConfirmation = false
    @State var tappedDayWorkout: Workout?
    @State var cachedProgressionSuggestions: [HomeProgressionSuggestion] = []

    var snapshot: HomeDashboardSnapshot { store.snapshot }
    var settings: UserSettings { snapshot.settings }
    var healthKitEnabled: Bool { snapshot.settings.healthKitEnabled }

    func totalCaffeineMg(at time: Date) -> Double {
        CaffeineEngine.totalMg(at: time, entries: snapshot.caffeineEntries, halfLifeHours: settings.caffeineHalfLife)
    }

    func caffeineClearTime(from now: Date) -> Date? {
        CaffeineEngine.clearTime(from: now, entries: snapshot.caffeineEntries, halfLifeHours: settings.caffeineHalfLife)
    }

    func suggestedBedtime(from now: Date) -> (time: Date, delayedByCaffeine: Bool) {
        CaffeineEngine.suggestedBedtime(from: now, entries: snapshot.caffeineEntries, halfLifeHours: settings.caffeineHalfLife)
    }

    var liveHealthSignals: HealthSignals {
        HealthSignals(
            todayHRV: hrv, averageHRV: averageHRV,
            todayRestingHR: restingHR, averageRestingHR: averageRestingHR,
            sleepMinutes: healthDataLoaded ? sleepMinutes : nil
        )
    }

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let name = settings.userName.isEmpty ? nil : settings.userName
        let timeGreeting: String
        switch hour {
        case 5..<12: timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        default: timeGreeting = "Good evening"
        }
        return name.map { "\(timeGreeting), \($0)" } ?? timeGreeting
    }

    var body: some View {
        homeDashboardChrome(homeScrollContent)
    }
}
