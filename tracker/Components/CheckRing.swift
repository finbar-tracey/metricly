import SwiftUI

/// The Session-Complete payoff mark (design_handoff_app, screen-finish.jsx):
/// a ring that draws in, then a checkmark that strokes over it. Restrained
/// celebration — one gesture, not confetti.
///
/// Honours Reduce Motion by rendering the finished state immediately rather
/// than animating (a check that never draws is still a check).
struct CheckRing: View {
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var ringDone = false
    @State private var checkDone = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(AppTheme.Dark.surfaceHi, lineWidth: 5)
            Circle()
                .trim(from: 0, to: ringDone ? 1 : 0)
                .stroke(accent, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .signalGlow(accent)
            CheckShape()
                .trim(from: 0, to: checkDone ? 1 : 0)
                .stroke(accent, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: 44, height: 44)
        }
        .frame(width: 112, height: 112)
        .accessibilityElement()
        .accessibilityLabel("Session complete")
        .onAppear {
            guard !reduceMotion else {
                ringDone = true
                checkDone = true
                return
            }
            withAnimation(.easeInOut(duration: 0.9).delay(0.1)) { ringDone = true }
            withAnimation(.easeOut(duration: 0.4).delay(0.85)) { checkDone = true }
        }
    }
}

/// The check glyph, as a trimmable path so it can stroke itself in.
struct CheckShape: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.width * 0.23, y: r.height * 0.52))
        p.addLine(to: CGPoint(x: r.width * 0.41, y: r.height * 0.70))
        p.addLine(to: CGPoint(x: r.width * 0.77, y: r.height * 0.30))
        return p
    }
}

#Preview {
    CheckRing(accent: AppTheme.Dark.Signal.recovery)
        .padding(60)
        .background(AppTheme.Dark.bg)
        .preferredColorScheme(.dark)
}
