import SwiftUI

extension ContentView {
    @ViewBuilder
    var sidebarDetailContent: some View {
        switch selectedSidebarItem {
        case .home, .none:      HomeDashboardView()
        case .workouts:         FullWorkoutListView()
        case .programs:         TrainingProgramsView().navigationTitle("Programs")
        case .schedule:         WorkoutScheduleView()
        case .calendar:         WorkoutCalendarView().navigationTitle("Calendar")
        case .cardio:           CardioHubView()
        case .activityLog:      ActivityLogView().navigationTitle("Activity Log")
        case .achievements:     AchievementsView()
        case .streak:           StreakCalendarView()
        case .personalRecords:  PersonalRecordsView()
        case .progressPhotos:   ProgressPhotosView()
        case .measurements:     BodyMeasurementsView()
        case .bodyWeight:       BodyWeightView()
        case .bodyFat:          BodyFatEstimateView()
        case .liftGoals:        LiftGoalsView()
        case .health:           HealthDashboardView()
        case .water:            WaterTrackerView()
        case .caffeine:         CaffeineTrackerView()
        case .creatine:         CreatineTrackerView()
        case .insights:         InsightsView().navigationTitle("Insights")
        case .exerciseLibrary:  ExerciseLibraryView().navigationTitle("Exercise Library")
        case .comparison:       WorkoutComparisonView().navigationTitle("Compare Workouts")
        case .smartSuggestions: SmartSuggestionsView()
        case .plateCalculator:  PlateCalculatorView()
        case .oneRepMax:        OneRepMaxView()
        case .workoutTimers:    WorkoutTimerView()
        case .settings:         SettingsView().navigationTitle("Settings")
        }
    }
}
