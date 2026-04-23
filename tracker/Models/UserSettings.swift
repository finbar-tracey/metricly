import Foundation
import SwiftData

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
        self.hasSeenOnboarding = false
        self.weeklyGoal = 0
        self.reminderDays = []
        self.reminderHour = 9
        self.reminderMinute = 0
        self.accentColorName = "blue"
        self.appearanceMode = "system"
        self.healthKitEnabled = false
        self.heightCm = 0
        self.biologicalSex = ""
        self.userName = ""
        self.focusModeReminder = false
        self.caffeineSensitivity = "Normal"
        self.dailyCaffeineLimit = 400
        self.dailyWaterGoalMl = 2500
        self.creatineDailyDose = 5.0
        self.creatineLoadingPhase = false
    }
}
