import SwiftUI

/// The Active-Workout signature: a countdown ring for the rest timer
/// (design_handoff_app, screen-active.jsx). Purely presentational — it renders
/// whatever `remaining`/`total` it's handed and owns no timer of its own, so it
/// stays testable and can't drift from `RestTimerController`.
struct RestTimerRing: View {
    /// Seconds left, counting down.
    let remaining: Int
    /// The full rest duration, for the trim fraction.
    let total: Int
    let accent: Color
    /// Small hint under the clock, e.g. "SET 3 NEXT". Hidden when nil.
    var nextHint: String?

    private var fraction: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(max(0, remaining)) / CGFloat(total)
    }

    private var clock: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Dark.surfaceHi, lineWidth: 8)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .signalGlow(accent, radius: 6)
                // The controller ticks twice a second; a 1s linear tween keeps
                // the sweep smooth rather than stepping.
                .animation(.linear(duration: 1), value: remaining)

            VStack(spacing: 2) {
                Text("REST")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(AppTheme.Dark.text3)
                Text(clock)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(AppTheme.Dark.text)
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy(duration: 0.3), value: remaining)
                if let nextHint {
                    Text(nextHint)
                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(accent)
                }
            }
        }
        .frame(width: 148, height: 148)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rest timer, \(remaining) seconds remaining")
    }
}

#Preview {
    RestTimerRing(remaining: 47, total: 90, accent: AppTheme.Dark.Signal.recovery, nextHint: "SET 3 NEXT")
        .padding(40)
        .background(AppTheme.Dark.bg)
        .preferredColorScheme(.dark)
}
