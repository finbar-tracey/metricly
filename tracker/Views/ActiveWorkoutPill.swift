import SwiftUI

/// Thin "Workout in progress" pill rendered in `ContentView`'s top safe-area
/// inset. Visible on every tab so the user can resume an open session without
/// hunting for it across tabs. Tapping invokes `onTap`, which the parent uses
/// to present the workout in a sheet.
struct ActiveWorkoutPill: View {
    let workout: Workout
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var displayName: String {
        workout.name.isEmpty ? String(localized: "Workout") : workout.name
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Circle()
                    .fill(AppTheme.Dark.Signal.strain)
                    .frame(width: 8, height: 8)
                    .opacity(reduceMotion ? 1.0 : (pulse ? 1.0 : 0.35))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                        value: pulse
                    )

                Text("In progress")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)

                Text(displayName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)

                if let start = workout.startTime {
                    // Only the elapsed text ticks; the rest of the pill is static.
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(elapsedText(since: start, now: context.date))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.thinMaterial, in: Capsule())
            .overlay(Capsule().stroke(AppTheme.Dark.Signal.strain.opacity(0.35), lineWidth: 1))
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout in progress, \(displayName)")
        .accessibilityHint("Opens the active workout")
        .onAppear { pulse = !reduceMotion }
    }

    /// Live mm:ss / h:mm:ss readout based on the workout's `startTime`.
    private func elapsedText(since start: Date, now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return Duration.seconds(seconds)
            .formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
