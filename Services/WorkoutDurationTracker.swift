import Foundation

/// Elapsed workout duration (no rest notifications).
@MainActor @Observable
final class WorkoutDurationTracker {
    var elapsedSeconds: Int = 0
    private var timer: Timer?
    private var startDate: Date?

    var formattedElapsed: String {
        let h = elapsedSeconds / 3600
        let m = (elapsedSeconds % 3600) / 60
        let s = elapsedSeconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    func start(from date: Date = .now) {
        startDate = date
        elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(date)))
        startTicking()
    }

    func sync(from date: Date) {
        startDate = date
        elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(date)))
        if timer == nil, date <= .now {
            startTicking()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func tearDown() {
        stop()
        startDate = nil
    }

    private func startTicking() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                guard let start = self.startDate else { return }
                self.elapsedSeconds = max(0, Int(Date.now.timeIntervalSince(start)))
            }
        }
    }
}
