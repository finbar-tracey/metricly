import SwiftUI

/// Light / dark / system — stored on `UserSettings.appearanceMode` (CloudKit-synced).
enum AppearanceMode {
    static let legacyAppStorageKey = "appearance"

    static func colorScheme(for mode: String) -> ColorScheme? {
        switch mode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    /// One-time migration from pre-unification `@AppStorage("appearance")`.
    static func migrateLegacyAppStorage(into settings: UserSettings) {
        guard let legacy = UserDefaults.standard.string(forKey: legacyAppStorageKey) else { return }
        guard ["light", "dark", "system"].contains(legacy) else { return }
        if settings.appearanceMode == "system", legacy != "system" {
            settings.appearanceMode = legacy
        }
        UserDefaults.standard.removeObject(forKey: legacyAppStorageKey)
    }
}
