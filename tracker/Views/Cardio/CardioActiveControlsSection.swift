import SwiftUI

extension CardioActiveView {

    var controlsRow: some View {
        HStack(spacing: 28) {
            Button {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                showStopAlert = true
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.red.opacity(0.20), Color.red.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.red.opacity(0.30), lineWidth: 1))
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.red)
                }
            }
            .buttonStyle(.pressableCard)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                tracker.recordManualLap()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.20), Color.blue.opacity(0.10)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                        .overlay(Circle().stroke(Color.blue.opacity(0.30), lineWidth: 1))
                    VStack(spacing: 1) {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.blue)
                        Text("LAP")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.pressableCard)
            .disabled(tracker.state != .active)
            .opacity(tracker.state == .active ? 1 : 0.45)

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if tracker.state == .active { tracker.pause() }
                else if tracker.state == .paused { tracker.resume() }
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [cardioType.color, cardioType.color.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 84, height: 84)
                        .shadow(color: cardioType.color.opacity(0.50), radius: 14, y: 5)
                        .overlay(Circle().stroke(.white.opacity(0.20), lineWidth: 0.5))
                    Image(systemName: tracker.state == .paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .buttonStyle(.pressableCard)
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: tracker.state)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                audioCues.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                            audioCues
                                ? AnyShapeStyle(LinearGradient(
                                    colors: [cardioType.color.opacity(0.20), cardioType.color.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                : AnyShapeStyle(Color(.tertiarySystemFill))
                        )
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(audioCues ? cardioType.color.opacity(0.30) : Color.clear, lineWidth: 1)
                        )
                    Image(systemName: audioCues ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(audioCues ? cardioType.color : .secondary)
                }
            }
            .buttonStyle(.pressableCard)
            .onChange(of: audioCues) { tracker.audioCuesEnabled = audioCues }
        }
        .padding(.vertical, 22)
    }
}
