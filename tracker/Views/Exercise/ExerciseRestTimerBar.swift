import SwiftUI

struct ExerciseRestTimerBar: View {
    @Bindable var controller: RestTimerController

    var body: some View {
        VStack(spacing: 10) {
            GradientProgressBar(
                value: Double(controller.restDuration - controller.restRemaining)
                    / Double(max(1, controller.restDuration)),
                color: controller.restRemaining <= 10 ? .red : .blue,
                height: 8
            )
            .accessibilityLabel("Rest timer: \(controller.restRemaining) seconds remaining")

            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    controller.adjust(by: -15)
                } label: {
                    timerButtonLabel("−15s")
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Subtract 15 seconds")

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    controller.adjust(by: 15)
                } label: {
                    timerButtonLabel("+15s")
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Add 15 seconds")

                Spacer()

                Text(controller.timerText)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(controller.restRemaining <= 10 ? .red : .primary)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: controller.restRemaining)
                    .accessibilityLabel("Rest timer: \(controller.timerText)")

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    controller.stop()
                } label: {
                    timerButtonLabel("Skip")
                }
                .buttonStyle(.pressableCard)
                .accessibilityLabel("Skip rest timer")
            }
        }
        .padding()
        .background(.thickMaterial)
    }

    private func timerButtonLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 15, weight: .bold, design: .rounded))
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .background(.thinMaterial, in: .capsule)
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
    }
}
