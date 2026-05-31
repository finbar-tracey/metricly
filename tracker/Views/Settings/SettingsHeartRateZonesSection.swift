import SwiftUI

struct SettingsHeartRateZonesSection: View {
    let settings: UserSettings

    var body: some View {
        Section {
            Stepper(value: Binding(
                get: { settings.maxHeartRate },
                set: { settings.maxHeartRate = $0 }
            ), in: 0...220) {
                HStack(spacing: 12) {
                    settingsSectionIcon("heart.fill", color: .red)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Max Heart Rate")
                        Text(settings.maxHeartRate == 0 ? "Auto" : "\(settings.maxHeartRate) bpm")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("Heart Rate Zones")
        } footer: {
            Text("Personalises your cardio heart-rate zones. Leave on Auto, or set your max HR — a common estimate is 220 − your age.")
        }
    }
}
