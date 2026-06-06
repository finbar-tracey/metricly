import SwiftUI

enum WorkoutTimerSections {

    static func modePickerCard(
        selectedMode: Binding<TimerMode>,
        onSelectMode: @escaping (TimerMode) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Timer Mode", icon: "timer", color: .accentColor)
            HStack(spacing: 8) {
                ForEach(TimerMode.allCases, id: \.self) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                            selectedMode.wrappedValue = mode
                            onSelectMode(mode)
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(selectedMode.wrappedValue == mode ? .white : .primary)
                            Text(mode.rawValue)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(selectedMode.wrappedValue == mode ? .white : .primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background {
                            if selectedMode.wrappedValue == mode {
                                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: Color.accentColor.opacity(0.45), radius: 8, y: 4)
                            } else {
                                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                                    .fill(Color(.secondarySystemFill))
                            }
                        }
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            Text(selectedMode.wrappedValue.description)
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 4)
        }
        .appCard()
    }

    static func settingsCard(
        selectedMode: TimerMode,
        controller: WorkoutIntervalTimerController
    ) -> some View {
        @Bindable var controller = controller
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Settings", icon: "slider.horizontal.3", color: .accentColor)
            VStack(spacing: 0) {
                switch selectedMode {
                case .emom:
                    settingRow("Duration", value: "\(controller.emomMinutes) min") {
                        Stepper("", value: $controller.emomMinutes, in: 1...60).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Interval", value: "\(controller.emomIntervalSeconds)s") {
                        Stepper("", value: $controller.emomIntervalSeconds, in: 15...120, step: 5).labelsHidden()
                    }
                case .amrap:
                    settingRow("Duration", value: "\(controller.amrapMinutes) min") {
                        Stepper("", value: $controller.amrapMinutes, in: 1...60).labelsHidden()
                    }
                case .tabata:
                    settingRow("Rounds", value: "\(controller.tabataRounds)") {
                        Stepper("", value: $controller.tabataRounds, in: 1...20).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Work Phase", value: "\(controller.tabataWork)s") {
                        Stepper("", value: $controller.tabataWork, in: 5...60, step: 5).labelsHidden()
                    }
                    Divider().padding(.leading, 16)
                    settingRow("Rest Phase", value: "\(controller.tabataRest)s") {
                        Stepper("", value: $controller.tabataRest, in: 5...60, step: 5).labelsHidden()
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    static func settingRow<T: View>(_ label: String, value: String, @ViewBuilder control: () -> T) -> some View {
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

    static func startCard(selectedMode: TimerMode, onStart: @escaping () -> Void) -> some View {
        Button(action: onStart) {
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

    static func activeHeroCard(
        controller: WorkoutIntervalTimerController,
        selectedModeColors: [Color],
        formatTime: @escaping (Int) -> String
    ) -> some View {
        HeroCard(palette: selectedModeColors) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    if controller.mode == .tabata {
                        Text(controller.isWorkPhase ? "WORK" : "REST")
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .tracking(2)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                            .foregroundStyle(.white)
                            .animation(.easeInOut(duration: 0.3), value: controller.isWorkPhase)
                    } else {
                        Text(TimerMode(controller.mode).rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                    }
                    Spacer()
                    if controller.mode == .emom || controller.mode == .tabata {
                        Text("Round \(controller.currentRound) / \(controller.totalRounds)")
                            .font(.caption.bold())
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                            .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                            .foregroundStyle(.white)
                    }
                }

                HStack(alignment: .center) {
                    Text(formatTime(controller.timeRemaining))
                        .font(.system(size: 80, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
                    Spacer()
                    ZStack {
                        Circle().stroke(.white.opacity(0.25), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: controller.progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: controller.progress)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                    }
                    .frame(width: 70, height: 70)
                }
            }
            .padding(22)
        }
    }

    static func activeControlCard(
        controller: WorkoutIntervalTimerController,
        formatTime: @escaping (Int) -> String,
        onStop: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if controller.mode == .amrap {
                SectionHeader(title: "Rounds Completed", icon: "repeat", color: .orange)
                HStack(spacing: 0) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        if controller.roundsCompleted > 0 { controller.roundsCompleted -= 1 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.pressableCard).frame(maxWidth: .infinity)
                    .accessibilityLabel("Decrease rounds")

                    AnimatedInt(
                        value: controller.roundsCompleted,
                        font: .system(size: 56, weight: .black, design: .rounded),
                        color: Color.accentColor
                    )
                    .frame(maxWidth: .infinity)

                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        controller.roundsCompleted += 1
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.pressableCard).frame(maxWidth: .infinity)
                    .accessibilityLabel("Increase rounds")
                }
                .padding(.vertical, 10)
            } else {
                SectionHeader(title: "Progress", icon: "chart.bar.fill", color: .accentColor)
                GradientProgressBar(value: controller.progress, color: .accentColor, height: 12)
                HStack {
                    Text("Elapsed: \(formatTime(controller.totalTime - controller.timeRemaining))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Remaining: \(formatTime(controller.timeRemaining))")
                        .font(.caption.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            Button(role: .destructive, action: onStop) {
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
}
