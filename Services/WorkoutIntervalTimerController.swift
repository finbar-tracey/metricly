import Foundation
import UserNotifications
import UIKit

/// EMOM / AMRAP / Tabata interval timer (end-date based, survives background).
@MainActor @Observable
final class WorkoutIntervalTimerController {
    enum Mode: String, CaseIterable {
        case emom = "EMOM"
        case amrap = "AMRAP"
        case tabata = "Tabata"
    }

    var mode: Mode = .emom
    var isRunning = false
    var timeRemaining = 0
    var totalTime = 0
    var currentRound = 1
    var totalRounds = 0
    var isWorkPhase = true
    var roundsCompleted = 0

    var emomMinutes = 10
    var emomIntervalSeconds = 60
    var amrapMinutes = 12
    var tabataRounds = 8
    var tabataWork = 20
    var tabataRest = 10

    private var timer: Timer?
    private(set) var timerEndDate: Date?
    private(set) var phaseEndDate: Date?

    private static let notificationID = "workoutTimerComplete"

    var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }

    func start() {
        let now = Date.now
        switch mode {
        case .emom:
            totalTime = emomMinutes * 60
            timeRemaining = emomIntervalSeconds
            totalRounds = max(1, emomMinutes * 60 / max(1, emomIntervalSeconds))
            currentRound = 1
            timerEndDate = now.addingTimeInterval(TimeInterval(totalTime))
            phaseEndDate = now.addingTimeInterval(TimeInterval(emomIntervalSeconds))
        case .amrap:
            totalTime = amrapMinutes * 60
            timeRemaining = totalTime
            roundsCompleted = 0
            timerEndDate = now.addingTimeInterval(TimeInterval(totalTime))
            phaseEndDate = timerEndDate
        case .tabata:
            totalRounds = tabataRounds
            currentRound = 1
            isWorkPhase = true
            timeRemaining = tabataWork
            totalTime = tabataRounds * (tabataWork + tabataRest)
            timerEndDate = now.addingTimeInterval(TimeInterval(totalTime))
            phaseEndDate = now.addingTimeInterval(TimeInterval(tabataWork))
        }
        isRunning = true
        scheduleNotification(seconds: totalTime)
        startDisplayTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        phaseEndDate = nil
        isRunning = false
        cancelNotification()
    }

    func finish(playFeedback: Bool = true) {
        stop()
        if playFeedback {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        }
    }

    func syncOnReturnToForeground() {
        guard isRunning, let overallEnd = timerEndDate else { return }
        if overallEnd.timeIntervalSinceNow <= 0 {
            finish()
            return
        }
        recalculateTimerState()
        if timer == nil { startDisplayTimer() }
    }

    func tearDown() {
        stop()
    }

    /// Test seam: simulate timer state after background without waiting.
    func applyTimingForTesting(
        mode: Mode,
        overallEnd: Date,
        phaseEnd: Date,
        totalTime: Int,
        timeRemaining: Int,
        currentRound: Int = 1,
        totalRounds: Int = 1,
        isWorkPhase: Bool = true
    ) {
        self.mode = mode
        self.totalTime = totalTime
        self.timeRemaining = timeRemaining
        self.currentRound = currentRound
        self.totalRounds = totalRounds
        self.isWorkPhase = isWorkPhase
        timerEndDate = overallEnd
        phaseEndDate = phaseEnd
        isRunning = true
    }

    private func startDisplayTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            Task { @MainActor in self.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard let phaseEnd = phaseEndDate, let overallEnd = timerEndDate else { return }
        if overallEnd.timeIntervalSinceNow <= 0 {
            finish()
            return
        }
        let phaseRemaining = Int(ceil(phaseEnd.timeIntervalSinceNow))
        if phaseRemaining <= 0 {
            advancePhase()
        } else {
            timeRemaining = phaseRemaining
            if phaseRemaining <= 3 {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    private func advancePhase() {
        let now = Date.now
        switch mode {
        case .emom:
            if currentRound < totalRounds {
                currentRound += 1
                phaseEndDate = now.addingTimeInterval(TimeInterval(emomIntervalSeconds))
                timeRemaining = emomIntervalSeconds
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                finish()
            }
        case .amrap:
            finish()
        case .tabata:
            if isWorkPhase {
                isWorkPhase = false
                phaseEndDate = now.addingTimeInterval(TimeInterval(tabataRest))
                timeRemaining = tabataRest
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else if currentRound < totalRounds {
                currentRound += 1
                isWorkPhase = true
                phaseEndDate = now.addingTimeInterval(TimeInterval(tabataWork))
                timeRemaining = tabataWork
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } else {
                finish()
            }
        }
    }

    private func recalculateTimerState() {
        guard let overallEnd = timerEndDate else { return }
        let overallRemaining = overallEnd.timeIntervalSinceNow
        let elapsed = TimeInterval(totalTime) - overallRemaining
        switch mode {
        case .amrap:
            timeRemaining = max(0, Int(ceil(overallRemaining)))
            phaseEndDate = overallEnd
        case .emom:
            let intervalSecs = TimeInterval(emomIntervalSeconds)
            let completedRounds = Int(elapsed / intervalSecs)
            currentRound = min(completedRounds + 1, totalRounds)
            let phaseLeft = intervalSecs - (elapsed - TimeInterval(completedRounds) * intervalSecs)
            phaseEndDate = Date.now.addingTimeInterval(phaseLeft)
            timeRemaining = max(0, Int(ceil(phaseLeft)))
        case .tabata:
            let cycleDuration = TimeInterval(tabataWork + tabataRest)
            let completedCycles = Int(elapsed / cycleDuration)
            let cycleElapsed = elapsed - TimeInterval(completedCycles) * cycleDuration
            currentRound = min(completedCycles + 1, totalRounds)
            if cycleElapsed < TimeInterval(tabataWork) {
                isWorkPhase = true
                let phaseLeft = TimeInterval(tabataWork) - cycleElapsed
                phaseEndDate = Date.now.addingTimeInterval(phaseLeft)
                timeRemaining = max(0, Int(ceil(phaseLeft)))
            } else {
                isWorkPhase = false
                let phaseLeft = cycleDuration - cycleElapsed
                phaseEndDate = Date.now.addingTimeInterval(phaseLeft)
                timeRemaining = max(0, Int(ceil(phaseLeft)))
            }
        }
    }

    private func scheduleNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        let content = UNMutableNotificationContent()
        content.title = "\(mode.rawValue) Complete"
        content.body = "Your workout timer has finished!"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, TimeInterval(seconds)), repeats: false)
        center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
    }

    private func cancelNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }
}
