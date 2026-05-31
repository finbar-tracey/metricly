import SwiftUI

enum TimerMode: String, CaseIterable {
    case emom = "EMOM"
    case amrap = "AMRAP"
    case tabata = "Tabata"

    init(_ mode: WorkoutIntervalTimerController.Mode) {
        switch mode {
        case .emom: self = .emom
        case .amrap: self = .amrap
        case .tabata: self = .tabata
        }
    }

    var controllerMode: WorkoutIntervalTimerController.Mode {
        switch self {
        case .emom: return .emom
        case .amrap: return .amrap
        case .tabata: return .tabata
        }
    }

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
    @State private var controller = WorkoutIntervalTimerController()

    private var selectedModeColors: [Color] { TimerMode(controller.mode).gradientColors }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if controller.isRunning {
                    WorkoutTimerSections.activeHeroCard(
                        controller: controller,
                        selectedModeColors: selectedModeColors,
                        formatTime: formatTime
                    )
                    WorkoutTimerSections.activeControlCard(
                        controller: controller,
                        formatTime: formatTime,
                        onStop: stopTimer
                    )
                } else {
                    WorkoutTimerSections.modePickerCard(
                        selectedMode: $selectedMode,
                        onSelectMode: { controller.mode = $0.controllerMode }
                    )
                    WorkoutTimerSections.settingsCard(
                        selectedMode: selectedMode,
                        controller: controller
                    )
                    WorkoutTimerSections.startCard(selectedMode: selectedMode, onStart: startTimer)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Workout Timers")
        .onDisappear { controller.tearDown() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active { controller.syncOnReturnToForeground() }
        }
    }

    private func startTimer() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        controller.mode = selectedMode.controllerMode
        controller.start()
    }

    private func stopTimer() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        controller.stop()
    }

    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    NavigationStack { WorkoutTimerView() }
}
