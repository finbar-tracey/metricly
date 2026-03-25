import Foundation
import SwiftData

@Model
final class UserSettings {
    var useKilograms: Bool = true
    var defaultRestDuration: Int = 90
    var autoStartRestTimer: Bool = false
    var hasSeenOnboarding: Bool = false

    init(useKilograms: Bool = true, defaultRestDuration: Int = 90, autoStartRestTimer: Bool = false) {
        self.useKilograms = useKilograms
        self.defaultRestDuration = defaultRestDuration
        self.autoStartRestTimer = autoStartRestTimer
        self.hasSeenOnboarding = false
    }
}
