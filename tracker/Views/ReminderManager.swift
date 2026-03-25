import Foundation
import UserNotifications

struct ReminderManager {
    private static let categoryID = "workoutReminder"

    static func scheduleReminders(days: [Int], hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()

        // Remove existing reminders
        center.removePendingNotificationRequests(withIdentifiers:
            (1...7).map { "reminder_day_\($0)" }
        )

        guard !days.isEmpty else { return }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }

            let messages = [
                "Time to hit the gym! Your muscles are waiting.",
                "Workout time! Let's make today count.",
                "Ready to train? Open Metricly to get started.",
                "Don't skip today! Your streak depends on it.",
                "It's gym o'clock. Let's go!",
                "Your future self will thank you. Time to train!",
                "Consistency beats perfection. Let's work out!"
            ]

            for day in days {
                let content = UNMutableNotificationContent()
                content.title = "Workout Reminder"
                content.body = messages[(day - 1) % messages.count]
                content.sound = .default
                content.categoryIdentifier = categoryID

                var dateComponents = DateComponents()
                dateComponents.weekday = day // 1 = Sunday, 7 = Saturday
                dateComponents.hour = hour
                dateComponents.minute = minute

                let trigger = UNCalendarNotificationTrigger(
                    dateMatching: dateComponents,
                    repeats: true
                )

                let request = UNNotificationRequest(
                    identifier: "reminder_day_\(day)",
                    content: content,
                    trigger: trigger
                )

                center.add(request)
            }
        }
    }

    static func removeAllReminders() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers:
            (1...7).map { "reminder_day_\($0)" }
        )
    }
}
