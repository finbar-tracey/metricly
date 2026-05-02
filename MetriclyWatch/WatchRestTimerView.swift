import SwiftUI
import WatchKit

// MARK: - WatchRestTimerView
//
// Full-screen rest timer shown automatically after logging a working set.
// Counts down from `duration` seconds, fires a haptic at 3 s and at 0 s,
// then auto-dismisses. The user can also dismiss early or add 15 s.

struct WatchRestTimerView: View {
    let duration: Int          // seconds to count down from

    @Environment(\.dismiss) private var dismiss
    @State private var remaining: Int = 0
    @State private var timer: Timer?
    @State private var finished = false

    // Progress 1.0 → 0.0
    private var progress: Double {
        duration > 0 ? Double(remaining) / Double(duration) : 0
    }

    private var timerColor: Color {
        if remaining <= 10 { return .red }
        if remaining <= 20 { return .orange }
        return .green
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(timerColor.opacity(0.2), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(timerColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: progress)

            VStack(spacing: 6) {
                if finished {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("Go!")
                        .font(.headline)
                } else {
                    Text(formatDuration(remaining))
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(timerColor)
                    Text("Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                // +15 s
                Button {
                    remaining += 15
                } label: {
                    Label("+15s", systemImage: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)

                Spacer()

                // Skip
                Button {
                    stop()
                    dismiss()
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
        .navigationTitle("Rest")
        .navigationBarBackButtonHidden(true)
    }

    // MARK: - Timer logic

    private func start() {
        remaining = duration
        finished  = false
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard remaining > 0 else { return }
            remaining -= 1

            if remaining == 3 {
                WKInterfaceDevice.current().play(.notification)
            }
            if remaining == 0 {
                WKInterfaceDevice.current().play(.success)
                finished = true
                stop()
                // Auto-dismiss after a brief moment
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}
