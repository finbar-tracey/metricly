import SwiftUI

struct SettingsRemindersTemplatesSection: View {
    let settings: UserSettings
    let templates: [Workout]

    var body: some View {
        Section {
            NavigationLink(value: SettingsRoute.reminders) {
                HStack(spacing: 12) {
                    settingsSectionIcon("bell.fill", color: .red)
                    Text("Reminders")
                    Spacer()
                    Text(remindersSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            NavigationLink(value: SettingsRoute.templates) {
                HStack(spacing: 12) {
                    settingsSectionIcon("doc.on.doc.fill", color: .purple)
                    Text("Templates")
                    Spacer()
                    Text(templatesSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var remindersSummary: String {
        if settings.reminderDays.isEmpty { return "Off" }
        let count = settings.reminderDays.count
        return "\(count) day\(count == 1 ? "" : "s")"
    }

    private var templatesSummary: String {
        templates.isEmpty ? "None saved" : "\(templates.count) saved"
    }
}
