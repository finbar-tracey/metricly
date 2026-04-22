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
    }
}
