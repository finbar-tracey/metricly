import SwiftUI

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
                .tint(selectedMode == .tabata ? (isWorkPhase ? .green : .orange) : .tint)
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

    private func startTimer() {
        switch selectedMode {
        case .emom:
            totalTime = emomMinutes * 60
            timeRemaining = emomIntervalSeconds
            totalRounds = emomMinutes * 60 / emomIntervalSeconds
            currentRound = 1
        case .amrap:
            totalTime = amrapMinutes * 60
            timeRemaining = totalTime
            roundsCompleted = 0
        case .tabata:
            totalRounds = tabataRounds
            currentRound = 1
            isWorkPhase = true
            timeRemaining = tabataWork
            totalTime = tabataRounds * (tabataWork + tabataRest)
        }

        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            tick()
        }
    }

    private func tick() {
        guard timeRemaining > 0 else { return }
        timeRemaining -= 1

        if timeRemaining <= 0 {
            switch selectedMode {
            case .emom:
                if currentRound < totalRounds {
                    currentRound += 1
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
                    timeRemaining = tabataRest
                    playBeep()
                } else {
                    if currentRound < totalRounds {
                        currentRound += 1
                        isWorkPhase = true
                        timeRemaining = tabataWork
                        playBeep()
                    } else {
                        finishTimer()
                    }
                }
            }
        }

        // Beep at 3, 2, 1
        if timeRemaining <= 3 && timeRemaining > 0 {
            playCountdownBeep()
        }
    }

    private func finishTimer() {
        stopTimer()
        playFinishBeep()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isRunning = false
    }

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
