import SwiftUI
import UserNotifications

enum TimerMode: String, CaseIterable {
    case emom = "EMOM"
    case amrap = "AMRAP"
    case tabata = "Tabata"

    var description: String {
        switch self {
        case .emom: return "Every Minute On the Minute"
        case .amrap: return "As Many Rounds As Possible"
        case .tabata: return "20s Work / 10s Rest × 8"
        }
    }

    var icon: String {
        switch self {
        case .emom: return "clock.arrow.circlepath"
        case .amrap: return "repeat"
        case .tabata: return "bolt.fill"
        }
    }
}

struct WorkoutTimerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMode: TimerMode = .emom
    @State private var isRunning = false

    // EMOM settings
    @State private var emomMinutes: Int = 10
    @State private var emomIntervalSeconds: Int = 60

    // AMRAP settings
    @State private var amrapMinutes: Int = 12

    // Tabata settings
    @State private var tabataRounds: Int = 8
    @State private var tabataWork: Int = 20
    @State private var tabataRest: Int = 10

    // Timer state
    @State private var timeRemaining: Int = 0
    @State private var totalTime: Int = 0
    @State private var currentRound: Int = 1
    @State private var totalRounds: Int = 0
    @State private var isWorkPhase: Bool = true
    @State private var timer: Timer?
    @State private var roundsCompleted: Int = 0

    // Date-based tracking for background survival
    @State private var timerEndDate: Date?
    @State private var phaseEndDate: Date?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Mode picker
                Picker("Mode", selection: $selectedMode) {
                    ForEach(TimerMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(isRunning)

                if !isRunning {
                    modeDescription
                    settingsSection
                    startButton
                } else {
                    activeTimerView
                }
            }
            .padding()
        }
        .navigationTitle("Workout Timers")
        .onDisappear {
            stopTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isRunning {
                guard let overallEnd = timerEndDate else { return }
                if overallEnd.timeIntervalSinceNow <= 0 {
                    finishTimer()
                    return
                }
                recalculateTimerState()
                if timer == nil {
                    startDisplayTimer()
                }
            }
        }
    }

    private var modeDescription: some View {
        VStack(spacing: 8) {
            Image(systemName: selectedMode.icon)
                .font(.system(size: 40))
                .foregroundStyle(.tint)
            Text(selectedMode.rawValue)
                .font(.title2.bold())
            Text(selectedMode.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var settingsSection: some View {
        VStack(spacing: 16) {
            switch selectedMode {
            case .emom:
                Stepper("Duration: \(emomMinutes) min", value: $emomMinutes, in: 1...60)
                Stepper("Interval: \(emomIntervalSeconds)s", value: $emomIntervalSeconds, in: 15...120, step: 5)
            case .amrap:
                Stepper("Duration: \(amrapMinutes) min", value: $amrapMinutes, in: 1...60)
            case .tabata:
                Stepper("Rounds: \(tabataRounds)", value: $tabataRounds, in: 1...20)
                Stepper("Work: \(tabataWork)s", value: $tabataWork, in: 5...60, step: 5)
                Stepper("Rest: \(tabataRest)s", value: $tabataRest, in: 5...60, step: 5)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var startButton: some View {
        Button {
            startTimer()
        } label: {
            Label("Start \(selectedMode.rawValue)", systemImage: "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding()
                .background(.tint, in: RoundedRectangle(cornerRadius: 16))
                .foregroundStyle(.white)
        }
    }

    private var activeTimerView: some View {
        VStack(spacing: 20) {
            // Phase indicator for Tabata
            if selectedMode == .tabata {
                Text(isWorkPhase ? "WORK" : "REST")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(isWorkPhase ? .green : .orange)
                    .animation(.easeInOut(duration: 0.3), value: isWorkPhase)
            }

            // Main countdown
            Text(formatTime(timeRemaining))
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())

            // Round info
            if selectedMode == .emom || selectedMode == .tabata {
                Text("Round \(currentRound) of \(totalRounds)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            if selectedMode == .amrap {
                VStack(spacing: 4) {
                    Text("Rounds Completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Button {
                            if roundsCompleted > 0 { roundsCompleted -= 1 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title)
                        }
                        Text("\(roundsCompleted)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Button {
                            roundsCompleted += 1
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title)
                        }
                    }
                }
            }

            // Progress bar
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .tint(selectedMode == .tabata ? (isWorkPhase ? .green : .orange) : .blue)
                .scaleEffect(y: 2)
                .padding(.horizontal)

            // Stop button
            Button(role: .destructive) {
                stopTimer()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Timer Control

    private func startTimer() {
        let now = Date.now
        switch selectedMode {
        case .emom:
            totalTime = emomMinutes * 60
            timeRemaining = emomIntervalSeconds
            totalRounds = emomMinutes * 60 / emomIntervalSeconds
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
        scheduleTimerNotification(seconds: totalTime)
        startDisplayTimer()
    }

    private func startDisplayTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            tick()
        }
    }

    private func tick() {
        guard let phaseEnd = phaseEndDate, let overallEnd = timerEndDate else { return }

        let overallRemaining = overallEnd.timeIntervalSinceNow
        if overallRemaining <= 0 {
            finishTimer()
            return
        }

        let phaseRemaining = Int(ceil(phaseEnd.timeIntervalSinceNow))

        if phaseRemaining <= 0 {
            advancePhase()
        } else {
            timeRemaining = phaseRemaining
            if phaseRemaining <= 3 && phaseRemaining > 0 {
                playCountdownBeep()
            }
        }
    }

    private func advancePhase() {
        let now = Date.now
        switch selectedMode {
        case .emom:
            if currentRound < totalRounds {
                currentRound += 1
                phaseEndDate = now.addingTimeInterval(TimeInterval(emomIntervalSeconds))
                timeRemaining = emomIntervalSeconds
                playBeep()
            } else {
                finishTimer()
            }
        case .amrap:
            finishTimer()
        case .tabata:
            if isWorkPhase {
                isWorkPhase = false
                phaseEndDate = now.addingTimeInterval(TimeInterval(tabataRest))
                timeRemaining = tabataRest
                playBeep()
            } else {
                if currentRound < totalRounds {
                    currentRound += 1
                    isWorkPhase = true
                    phaseEndDate = now.addingTimeInterval(TimeInterval(tabataWork))
                    timeRemaining = tabataWork
                    playBeep()
                } else {
                    finishTimer()
                }
            }
        }
    }

    private func recalculateTimerState() {
        guard let overallEnd = timerEndDate else { return }
        let overallRemaining = overallEnd.timeIntervalSinceNow
        let elapsed = TimeInterval(totalTime) - overallRemaining

        switch selectedMode {
        case .amrap:
            timeRemaining = max(0, Int(ceil(overallRemaining)))
            phaseEndDate = overallEnd
        case .emom:
            let intervalSecs = TimeInterval(emomIntervalSeconds)
            let completedRounds = Int(elapsed / intervalSecs)
            currentRound = min(completedRounds + 1, totalRounds)
            let phaseElapsed = elapsed - TimeInterval(completedRounds) * intervalSecs
            let phaseLeft = intervalSecs - phaseElapsed
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

    private func finishTimer() {
        stopTimer()
        playFinishBeep()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerEndDate = nil
        phaseEndDate = nil
        isRunning = false
        cancelTimerNotification()
    }

    // MARK: - Notifications

    private static let workoutTimerNotificationID = "workoutTimerComplete"

    private func scheduleTimerNotification(seconds: Int) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        center.removePendingNotificationRequests(withIdentifiers: [Self.workoutTimerNotificationID])

        let content = UNMutableNotificationContent()
        content.title = "\(selectedMode.rawValue) Complete"
        content.body = "Your workout timer has finished!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, TimeInterval(seconds)), repeats: false)
        let request = UNNotificationRequest(identifier: Self.workoutTimerNotificationID, content: content, trigger: trigger)
        center.add(request)
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.workoutTimerNotificationID])
    }

    // MARK: - Haptics

    private func playBeep() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    private func playCountdownBeep() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }

    private func playFinishBeep() {
        #if os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        #endif
    }
}

#Preview {
    NavigationStack {
        WorkoutTimerView()
    }
}
