import Foundation
import SwiftData
import SwiftUI

enum AppAccentColor: String, CaseIterable, Identifiable {
    case blue, indigo, purple, pink, red, orange, green, teal
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .blue: return .blue
        case .indigo: return .indigo
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .green: return .green
        case .teal: return .teal
        }
    }
}

@Model
final class UserSettings {
    var useKilograms: Bool = true
    var defaultRestDuration: Int = 90
    var autoStartRestTimer: Bool = false
    var hasSeenOnboarding: Bool = false
    var weeklyGoal: Int = 0
    var reminderDays: [Int] = []
    var reminderHour: Int = 9
    var reminderMinute: Int = 0
    var accentColorName: String = "blue"
    var appearanceMode: String = "system"
    var healthKitEnabled: Bool = false
    var heightCm: Double = 0
    var biologicalSex: String = "" // "male" or "female"
    var userName: String = ""
    var focusModeReminder: Bool = false
    var caffeineSensitivity: String = "Normal" // Slow / Normal / Fast
    var dailyCaffeineLimit: Int = 400 // mg
    var dailyWaterGoalMl: Int = 2500 // ml
    var creatineDailyDose: Double = 5.0 // grams
    var creatineLoadingPhase: Bool = false // loading phase = 20g/day for first week

    // Cardio goals
    var weeklyCardioDistanceGoalKm: Double = 0   // 0 = not set
    var weeklyCardioSessionGoal: Int       = 0   // 0 = not set

    // Weekly workout schedule — JSON [weekday: name], weekday 1=Sun … 7=Sat
    var weeklyPlanData: Data? = nil

    var weeklyPlan: [Int: String] {
        get { (try? JSONDecoder().decode([Int: String].self, from: weeklyPlanData ?? Data())) ?? [:] }
        set { weeklyPlanData = try? JSONEncoder().encode(newValue) }
    }

    var accentColor: AppAccentColor {
        get { AppAccentColor(rawValue: accentColorName) ?? .blue }
        set { accentColorName = newValue.rawValue }
    }

    var caffeineSensitivityEnum: CaffeineEntry.Sensitivity {
        get { CaffeineEntry.Sensitivity(rawValue: caffeineSensitivity) ?? .normal }
        set { caffeineSensitivity = newValue.rawValue }
    }

    var caffeineHalfLife: Double {
        caffeineSensitivityEnum.halfLifeHours
    }

    init(useKilograms: Bool = true, defaultRestDuration: Int = 90, autoStartRestTimer: Bool = false) {
        self.useKilograms = useKilograms
        self.defaultRestDuration = defaultRestDuration
        self.autoStartRestTimer = autoStartRestTimer
    }
}
