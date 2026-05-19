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

    var gradientColors: [Color] {
        switch self {
        case .emom: return [.blue, .cyan.opacity(0.7)]
        case .amrap: return [.orange, .red.opacity(0.7)]
        case .tabata: return [.purple, .pink.opacity(0.7)]
        }
    }
}

struct WorkoutTimerView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedMode: TimerMode = .emom
    @State private var isRunning = false

    @State private var emomMinutes: Int = 10
    @State private var emomIntervalSeconds: Int = 60
    @State private var amrapMinutes: Int = 12
    @State private var tabataRounds: Int = 8
    @State private var tabataWork: Int = 20
    @State private var tabataRest: Int = 10

    @State private var timeRemaining: Int = 0
    @State private var totalTime: Int = 0
    @State private var currentRound: Int = 1
    @State private var totalRounds: Int = 0
    @State private var isWorkPhase: Bool = true
    @State private var timer: Timer?
    @State private var roundsCompleted: Int = 0
    @State private var timerEndDate: Date?
    @State private var phaseEndDate: Date?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isRunning {
                    activeHeroCard
                    activeControlCard
                } else {
                    modePickerCard
                    settingsCard
                    startCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Workout Timers")
        .onDisappear { stopTimer() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && isRunning {
                guard let overallEnd = timerEndDate else { return }
                if overallEnd.timeIntervalSinceNow <= 0 { finishTimer(); return }
                recalculateTimerState()
                if timer == nil { startDisplayTimer() }
            }
        }
    }

    // MARK: - Mode Picker Card

    private var modePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Timer Mode", icon: "timer", color: .accentColor)
            HStack(spacing: 8) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { selectedMode = mode }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(selectedMode == mode ? .white : .primary)
                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedMode == mode ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if selectedMode == mode {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.accentColor.opacity(0.45), radius: 8, y: 4)
                            } else {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.secondarySystemFill))
                            }
                        }
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            Text(selectedMode.description)
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .appCard()
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Settings", icon: "slider.horizontal.3", color: .accentColor)

            VStack(spacing: 0) {
                switch selectedMode {
                case .emom:
                    settingRow("Duration", value: "\(emomMinutes) min") {
                        Stepper("", value: $emomMinutes, in: 1...60).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Interval", value: "\(emomIntervalSeconds)s") {
                        Stepper("", value: $emomIntervalSeconds, in: 15...120, step: 5).labelsHidden()
                    }
                case .amrap:
                    settingRow("Duration", value: "\(amrapMinutes) min") {
                        Stepper("", value: $amrapMinutes, in: 1...60).labelsHidden()
                    }
                case .tabata:
                    settingRow("Rounds", value: "\(tabataRounds)") {
                        Stepper("", value: $tabataRounds, in: 1...20).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Work Phase", value: "\(tabataWork)s") {
                        Stepper("", value: $tabataWork, in: 5...60, step: 5).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Rest Phase", value: "\(tabataRest)s") {
                        Stepper("", value: $tabataRest, in: 5...60, step: 5).labelsHidden()
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    private func settingRow<T: View>(_ label: String, value: String, @ViewBuilder control: () -> T) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
            Spacer()
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.accentColor)
            control()
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }

    // MARK: - Start Card

    private var startCard: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            startTimer()
        } label: {
            Label("Start \(selectedMode.rawValue)", systemImage: "play.fill")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    LinearGradient(colors: selectedMode.gradientColors,
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 0.5)
                )
                .shadow(color: (selectedMode.gradientColors.first ?? .clear).opacity(0.50), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.pressableCard)
        .padding(.horizontal)
    }

    // MARK: - Active Hero Card

    private var activeHeroCard: some View {
        HeroCard(palette: selectedMode.gradientColors) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    if selectedMode == .tabata {
                        Text(isWorkPhase ? "WORK" : "REST")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(2)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                            .foregroundStyle(.white)
                            .animation(.easeInOut(duration: 0.3), value: isWorkPhase)
                    } else {
                        Text(selectedMode.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    Spacer()
                    if selectedMode == .emom || selectedMode == .tabata {
                        Text("Round \(currentRound) / \(totalRounds)")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                            .foregroundStyle(.white)
                    }
                }

                HStack(alignment: .center) {
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    Spacer()
                    ZStack {
                        Circle().stroke(.white.opacity(0.25), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: progress)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                    }
                    .frame(width: 70, height: 70)
                }
            }
            .padding(22)
        }
    }

    // MARK: - Active Control Card

    private var activeControlCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if selectedMode == .amrap {
                SectionHeader(title: "Rounds Completed", icon: "repeat", color: .orange)
                HStack(spacing: 0) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if roundsCompleted > 0 { roundsCompleted -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.pressableCard).frame(maxWidth: .infinity)

                    AnimatedInt(
                        value: roundsCompleted,
                        font: .system(size: 56, weight: .black, design: .rounded),
                        color: Color.accentColor
                    )
                    .frame(maxWidth: .infinity)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        roundsCompleted += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.pressableCard).frame(maxWidth: .infinity)
                }
                .padding(.vertical, 10)
            } else {
                SectionHeader(title: "Progress", icon: "chart.bar.fill", color: .accentColor)
                GradientProgressBar(value: progress, color: .accentColor, height: 12)
                HStack {
                    Text("Elapsed: \(formatTime(totalTime - timeRemaining))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Remaining: \(formatTime(timeRemaining))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Button(role: .destructive) {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                stopTimer()
            } label: {
                Label("Stop Timer", systemImage: "stop.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [Color.red.opacity(0.18), Color.red.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous)
                            .stroke(Color.red.opacity(0.20), lineWidth: 0.5)
                    )
            }
            .buttonStyle(.pressableCard)
        }
        .appCard()
    }

    // MARK: - Computed

    private var progress: Double {
        guard totalTime > 0 else { return 0 }
        return Double(totalTime - timeRemaining) / Double(totalTime)
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60; let s = seconds % 60
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
            currentRound = 1; isWorkPhase = true
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in tick() }
    }

    private func tick() {
        guard let phaseEnd = phaseEndDate, let overallEnd = timerEndDate else { return }
        if overallEnd.timeIntervalSinceNow <= 0 { finishTimer(); return }
        let phaseRemaining = Int(ceil(phaseEnd.timeIntervalSinceNow))
        if phaseRemaining <= 0 { advancePhase() } else {
            timeRemaining = phaseRemaining
            if phaseRemaining <= 3 { playCountdownBeep() }
        }
    }

    private func advancePhase() {
        let now = Date.now
        switch selectedMode {
        case .emom:
            if currentRound < totalRounds {
                currentRound += 1
                phaseEndDate = now.addingTimeInterval(TimeInterval(emomIntervalSeconds))
                timeRemaining = emomIntervalSeconds; playBeep()
            } else { finishTimer() }
        case .amrap: finishTimer()
        case .tabata:
            if isWorkPhase {
                isWorkPhase = false
                phaseEndDate = now.addingTimeInterval(TimeInterval(tabataRest))
                timeRemaining = tabataRest; playBeep()
            } else {
                if currentRound < totalRounds {
                    currentRound += 1; isWorkPhase = true
                    phaseEndDate = now.addingTimeInterval(TimeInterval(tabataWork))
                    timeRemaining = tabataWork; playBeep()
                } else { finishTimer() }
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

    private func finishTimer() { stopTimer(); playFinishBeep() }

    private func stopTimer() {
        timer?.invalidate(); timer = nil
        timerEndDate = nil; phaseEndDate = nil
        isRunning = false; cancelTimerNotification()
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
        center.add(UNNotificationRequest(identifier: Self.workoutTimerNotificationID, content: content, trigger: trigger))
    }

    private func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.workoutTimerNotificationID])
    }

    // MARK: - Haptics

    private func playBeep() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    private func playCountdownBeep() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    private func playFinishBeep() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
}

#Preview {
    NavigationStack { WorkoutTimerView() }
}
