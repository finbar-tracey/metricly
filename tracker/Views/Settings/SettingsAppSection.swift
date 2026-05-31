import SwiftUI

struct SettingsAppSection: View {
    @Environment(\.appServices) private var appServices
    let settings: UserSettings
    let workoutsEmpty: Bool
    let cardioSessionsEmpty: Bool
    let onExportWorkouts: () -> Void
    let onExportCardio: () -> Void
    let onExportPDF: () -> Void
    let onImport: () -> Void

    var body: some View {
        Section {
            HStack(spacing: 12) {
                settingsSectionIcon("heart.fill", color: .red)
                Toggle("Sync with Apple Health", isOn: Binding(
                    get: { settings.healthKitEnabled },
                    set: { newValue in
                        settings.healthKitEnabled = newValue
                        if newValue {
                            Task { try? await appServices.healthKit.requestAuthorization() }
                        }
                    }
                ))
            }
            Button(action: onExportWorkouts) {
                HStack(spacing: 12) {
                    settingsSectionIcon("square.and.arrow.up", color: .blue)
                    Text("Export Workouts as CSV")
                }
            }
            .disabled(workoutsEmpty)
            Button(action: onExportCardio) {
                HStack(spacing: 12) {
                    settingsSectionIcon("figure.run", color: .orange)
                    Text("Export Cardio as CSV")
                }
            }
            .disabled(cardioSessionsEmpty)
            Button(action: onExportPDF) {
                HStack(spacing: 12) {
                    settingsSectionIcon("doc.richtext", color: .red)
                    Text("Export Workouts as PDF")
                }
            }
            .disabled(workoutsEmpty)
            Button(action: onImport) {
                HStack(spacing: 12) {
                    settingsSectionIcon("square.and.arrow.down", color: .green)
                    Text("Import Workouts from CSV")
                }
            }
        } header: {
            Text("Health & Data")
        } footer: {
            Text("Completed workouts and body weight entries will be saved to Apple Health.")
        }
    }
}
