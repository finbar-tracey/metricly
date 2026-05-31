import SwiftUI

struct SettingsPreferencesSection: View {
    let settings: UserSettings
    @Binding var celebrationsEnabled: Bool

    var body: some View {
        Section {
            HStack(spacing: 12) {
                settingsSectionIcon("timer", color: .orange)
                Stepper(
                    "Default Rest: \(settings.defaultRestDuration)s",
                    value: Binding(
                        get: { settings.defaultRestDuration },
                        set: { settings.defaultRestDuration = $0 }
                    ),
                    in: 15...300,
                    step: 15
                )
            }
            HStack(spacing: 12) {
                settingsSectionIcon("play.circle", color: .green)
                Toggle("Auto-start Rest Timer", isOn: Binding(
                    get: { settings.autoStartRestTimer },
                    set: { settings.autoStartRestTimer = $0 }
                ))
            }
            HStack(spacing: 12) {
                settingsSectionIcon("moon.circle.fill", color: .indigo)
                Toggle("Focus Mode Reminder", isOn: Binding(
                    get: { settings.focusModeReminder },
                    set: { settings.focusModeReminder = $0 }
                ))
            }
            HStack(spacing: 12) {
                settingsSectionIcon("party.popper.fill", color: .pink)
                Toggle("Celebrations", isOn: $celebrationsEnabled)
            }
            HStack(spacing: 12) {
                settingsSectionIcon("target", color: .red)
                Stepper(
                    "Weekly Goal: \(settings.weeklyGoal == 0 ? "Off" : "\(settings.weeklyGoal)x")",
                    value: Binding(
                        get: { settings.weeklyGoal },
                        set: { settings.weeklyGoal = $0 }
                    ),
                    in: 0...7
                )
            }
        } header: {
            Text("Workout")
        } footer: {
            Text("Focus reminder prompts you to enable a Fitness Focus when starting a workout. Celebrations show full-screen banners for new PRs, goals hit, and achievements unlocked.")
        }
    }
}
