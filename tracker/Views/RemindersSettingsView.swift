import SwiftUI
import SwiftData

/// Edits the workout reminder schedule: which weekdays to nudge and the
/// time-of-day. Reached from the Reminders row in `SettingsView` via
/// `SettingsRoute.reminders`. Re-schedules via `ReminderManager` on every
/// change so the parent doesn't need to wire its own callback.
struct RemindersSettingsView: View {
    @Query private var settingsArray: [UserSettings]
    @Environment(\.modelContext) private var modelContext

    private var settings: UserSettings {
        if let existing = settingsArray.first { return existing }
        let new = UserSettings()
        modelContext.insert(new)
        return new
    }

    /// Driven into a `DatePicker` and written back to `reminderHour` /
    /// `reminderMinute` whenever the user changes the time.
    @State private var reminderDate: Date = .now

    private static let weekdaySymbols: [(Int, String)] = [
        (1, "Sun"), (2, "Mon"), (3, "Tue"), (4, "Wed"),
        (5, "Thu"), (6, "Fri"), (7, "Sat")
    ]

    var body: some View {
        Form {
            Section {
                ForEach(Self.weekdaySymbols, id: \.0) { weekday, name in
                    Toggle(isOn: dayBinding(for: weekday)) {
                        Text(name)
                    }
                }
            } header: {
                Text("Days")
            } footer: {
                Text("Pick the days you want a workout nudge.")
            }

            Section {
                DatePicker(
                    "Reminder time",
                    selection: $reminderDate,
                    displayedComponents: .hourAndMinute
                )
                .onChange(of: reminderDate) { _, newValue in
                    let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                    settings.reminderHour = components.hour ?? 9
                    settings.reminderMinute = components.minute ?? 0
                    rescheduleReminders()
                }
            } header: {
                Text("Time")
            }
        }
        .navigationTitle("Reminders")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { syncDateFromSettings() }
    }

    private func dayBinding(for weekday: Int) -> Binding<Bool> {
        Binding(
            get: { settings.reminderDays.contains(weekday) },
            set: { isOn in
                var days = Set(settings.reminderDays)
                if isOn { days.insert(weekday) } else { days.remove(weekday) }
                settings.reminderDays = days.sorted()
                rescheduleReminders()
            }
        )
    }

    private func syncDateFromSettings() {
        var components = DateComponents()
        components.hour = settings.reminderHour
        components.minute = settings.reminderMinute
        reminderDate = Calendar.current.date(from: components) ?? .now
    }

    private func rescheduleReminders() {
        if settings.reminderDays.isEmpty {
            ReminderManager.removeAllReminders()
        } else {
            ReminderManager.scheduleReminders(
                days: settings.reminderDays,
                hour: settings.reminderHour,
                minute: settings.reminderMinute
            )
        }
    }
}
