import SwiftUI

extension ContentView {
    enum AppTab: Hashable {
        case home, training, health, more
    }

    enum SidebarItem: String, Hashable, CaseIterable {
        // Home
        case home = "Home"
        // Track
        case workouts = "Workouts"
        case programs = "Programs"
        case schedule = "Schedule"
        case calendar = "Calendar"
        case cardio = "Cardio"
        case activityLog = "Activity Log"
        // Progress
        case achievements = "Achievements"
        case streak = "Streak"
        case personalRecords = "Personal Records"
        case progressPhotos = "Progress Photos"
        case measurements = "Measurements"
        case bodyWeight = "Body Weight"
        case bodyFat = "Body Fat %"
        case liftGoals = "Lift Goals"
        // Health
        case health = "Health"
        case water = "Water"
        case caffeine = "Caffeine"
        case creatine = "Creatine"
        // Analyze
        case insights = "Insights"
        case exerciseLibrary = "Exercise Library"
        case comparison = "Compare"
        case smartSuggestions = "Smart Suggestions"
        // Tools
        case plateCalculator = "Plate Calculator"
        case oneRepMax = "1RM Calculator"
        case workoutTimers = "Workout Timers"
        // Settings
        case settings = "Settings"

        var icon: String {
            switch self {
            case .home:             return "house"
            case .workouts:         return "dumbbell"
            case .programs:         return "calendar.badge.clock"
            case .schedule:         return "calendar.badge.checkmark"
            case .calendar:         return "calendar"
            case .cardio:           return "figure.run"
            case .activityLog:      return "list.bullet.rectangle"
            case .achievements:     return "medal"
            case .streak:           return "flame"
            case .personalRecords:  return "trophy"
            case .progressPhotos:   return "camera"
            case .measurements:     return "ruler"
            case .bodyWeight:       return "scalemass"
            case .liftGoals:        return "target"
            case .insights:         return "chart.bar"
            case .exerciseLibrary:  return "books.vertical"
            case .comparison:       return "arrow.left.arrow.right"
            case .smartSuggestions: return "lightbulb"
            case .plateCalculator:  return "circle.grid.cross"
            case .oneRepMax:        return "function"
            case .workoutTimers:    return "timer"
            case .caffeine:         return "cup.and.saucer.fill"
            case .bodyFat:          return "percent"
            case .health:           return "heart.text.square"
            case .water:            return "drop.fill"
            case .creatine:         return "pill.fill"
            case .settings:         return "gearshape"
            }
        }
    }
}
