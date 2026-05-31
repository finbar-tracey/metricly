import SwiftUI

struct SettingsNutritionSection: View {
    let settings: UserSettings

    var body: some View {
        Section {
            HStack(spacing: 12) {
                settingsSectionIcon("cup.and.saucer.fill", color: .brown)
                Picker("Caffeine sensitivity", selection: Binding(
                    get: { settings.caffeineSensitivityEnum },
                    set: { settings.caffeineSensitivityEnum = $0 }
                )) {
                    ForEach(CaffeineEntry.Sensitivity.allCases) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }
            HStack(spacing: 12) {
                settingsSectionIcon("gauge.open.with.lines.needle.33percent.and.arrowtriangle", color: .orange)
                Stepper(
                    "Daily caffeine: \(settings.dailyCaffeineLimit) mg",
                    value: Binding(
                        get: { settings.dailyCaffeineLimit },
                        set: { settings.dailyCaffeineLimit = $0 }
                    ),
                    in: 100...800, step: 50
                )
            }
            HStack(spacing: 12) {
                settingsSectionIcon("drop.fill", color: .cyan)
                Stepper(
                    "Daily water: \(settings.dailyWaterGoalMl) ml",
                    value: Binding(
                        get: { settings.dailyWaterGoalMl },
                        set: { settings.dailyWaterGoalMl = $0 }
                    ),
                    in: 1000...5000, step: 250
                )
            }
            HStack(spacing: 12) {
                settingsSectionIcon("pill.fill", color: .blue)
                Stepper(
                    "Creatine: \(String(format: "%.0f", settings.creatineDailyDose))g / day",
                    value: Binding(
                        get: { settings.creatineDailyDose },
                        set: { settings.creatineDailyDose = $0 }
                    ),
                    in: 1...25, step: 1
                )
            }
            HStack(spacing: 12) {
                settingsSectionIcon("bolt.fill", color: .yellow)
                Toggle("Creatine loading phase", isOn: Binding(
                    get: { settings.creatineLoadingPhase },
                    set: { settings.creatineLoadingPhase = $0 }
                ))
            }
        } header: {
            Text("Nutrition")
        } footer: {
            Text("Loading phase uses 20g/day for 5–7 days, then switches to maintenance dose.")
        }
    }
}
