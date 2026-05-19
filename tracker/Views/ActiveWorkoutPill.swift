import SwiftUI

/// Thin "Workout in progress" pill rendered in `ContentView`'s top safe-area
/// inset. Visible on every tab so the user can resume an open session without
/// hunting for it across tabs. Tapping invokes `onTap`, which the parent uses
/// to present the workout in a sheet.
struct ActiveWorkoutPill: View {
    let workout: Workout
    let onTap: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: onTap) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 10) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                        .opacity(pulse ? 1.0 : 0.35)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

                    Text("In progress")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)

                    Text(workout.name.isEmpty ? "Workout" : workout.name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    if let elapsed = elapsedText(now: context.date) {
                        Text(elapsed)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.thinMaterial, in: Capsule())
                .overlay(Capsule().stroke(.red.opacity(0.35), lineWidth: 1))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
        }
        .buttonStyle(.plain)
        .onAppear { pulse = true }
    }

    /// Live mm:ss / h:mm:ss readout based on the workout's `startTime`.
    /// `now` is supplied by the enclosing `TimelineView` so the pill stays
    /// accurate without forcing the parent to re-render.
    private func elapsedText(now: Date) -> String? {
        guard let start = workout.startTime else { return nil }
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }
}
