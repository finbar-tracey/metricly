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

    // MARK: - Streak nudge (fires at 8pm on scheduled workout days)

    /// Schedule a "you haven't trained yet" nudge at 20:00 on each scheduled day.
    /// Call this whenever workout days / settings change. Call `cancelTodayStreakNudge()`
    /// immediately after a workout is saved so the nudge doesn't fire.
    static func scheduleStreakNudges(days: [Int]) {
        let center = UNUserNotificationCenter.current()
        // Remove old nudges
        center.removePendingNotificationRequests(withIdentifiers:
            (1...7).map { "nudge_day_\($0)" }
        )
        guard !days.isEmpty else { return }

        let nudgeMessages = [
            "Still time to train today! Your streak is worth protecting. 🔥",
            "Haven't logged a workout yet today — let's keep that streak alive!",
            "Your muscles are waiting. Log a quick session before midnight! 💪",
            "Don't let the streak die today. Even 20 minutes counts.",
            "One workout away from keeping your streak. You've got this!",
        ]

        for day in days {
            let content = UNMutableNotificationContent()
            content.title = "Workout reminder 🔥"
            content.body = nudgeMessages[day % nudgeMessages.count]
            content.sound = .default

            var components = DateComponents()
            components.weekday = day
            components.hour = 20
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "nudge_day_\(day)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }

    /// Call after saving a workout to dismiss today's nudge.
    static func cancelTodayStreakNudge() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        let id = "nudge_day_\(weekday)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [id])
    }
}
