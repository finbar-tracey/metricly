import Foundation
import AudioToolbox
import UIKit
import UserNotifications

/// Shared rest-timer state for workout views (testable, `@Observable`).
@MainActor @Observable
final class RestTimerController {
    var restDuration = 90
    var restRemaining = 0
    var timerActive = false

    private var timer: Timer?
    private(set) var timerEndDate: Date?

    var timerText: String {
        let minutes = restRemaining / 60
        let seconds = restRemaining % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private static let notificationID = "restTimerComplete"

    func start() {
        timer?.invalidate()
        timer = nil
        let endDate = Date.now.addingTimeInterval(TimeInterval(restDuration))
        timerEndDate = endDate
        restRemaining = restDuration
        timerActive = true
        scheduleNotification(seconds: restDuration)
        startDisplayTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        timerActive = false
        cancelNotification()
    }

    func adjust(by amount: Int) {
        if let endDate = timerEndDate {
            timerEndDate = endDate.addingTimeInterval(TimeInterval(amount))
            restRemaining = max(0, Int(ceil(timerEndDate!.timeIntervalSinceNow)))
        } else {
            restRemaining = max(0, restRemaining + amount)
        }
        restDuration = max(15, restDuration + amount)
        if timerActive {
            scheduleNotification(seconds: restRemaining)
        }
    }

    func syncOnReturnToForeground() {
        guard let endDate = timerEndDate else { return }
        let remaining = Int(ceil(endDate.timeIntervalSinceNow))
        if remaining <= 0 {
            finishTimer(playFeedback: true)
        } else {
            restRemaining = remaining
            if timer == nil { startDisplayTimer() }
        }
    }

    func tearDown() {
        stop()
        cancelNotification()
    }

    private func startDisplayTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] t in
            guard let self else { t.invalidate(); return }
            Task { @MainActor in
                guard let endDate = self.timerEndDate else { t.invalidate(); return }
                let remaining = Int(ceil(endDate.timeIntervalSinceNow))
                if remaining > 0 {
                    self.restRemaining = remaining
                } else {
                    t.invalidate()
                    self.finishTimer(playFeedback: true)
                }
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func finishTimer(playFeedback: Bool) {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        restRemaining = 0
        timerActive = false
        cancelNotification()
        if playFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            AudioServicesPlayAlertSound(SystemSoundID(1005))
        }
    }

    private func scheduleNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body = "Time to start your next set!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, TimeInterval(seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}
