import Foundation
import UserNotifications

struct ReminderManager {
    private static let categoryID = "workoutReminder"

    /// Register the notification category with action buttons.
    static func registerCategory() {
        let startAction = UNNotificationAction(
            identifier: "startWorkout",
            title: "Start Workout",
            options: .foreground
        )
        let category = UNNotificationCategory(
            identifier: categoryID,
            actions: [startAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    /// Check current notification authorization status.
    static func checkAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func scheduleReminders(days: [Int], hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()

        // Remove existing reminders
        center.removePendingNotificationRequests(withIdentifiers:
            (1...7).map { "reminder_day_\($0)" }
        )

        guard !days.isEmpty else { return }

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error {
                print("Notification authorization error: \(error.localizedDescription)")
            }
            guard granted else { return }

            registerCategory()

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

                center.add(request) { error in
                    if let error {
                        print("Failed to schedule reminder for day \(day): \(error.localizedDescription)")
                    }
                }
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
