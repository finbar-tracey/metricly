import SwiftUI

/// The rest panel shown between sets while the timer runs — the Active-Workout
/// signature from the v2 handoff (design_handoff_app, screen-active.jsx):
/// the countdown `RestTimerRing`, a coaching nudge, and the ±15 / Skip controls.
///
/// This is a self-contained dark HUD pinned to the bottom during rest, so it
/// reads as a distinct "resting" mode over the (still light) logging list — the
/// rest of `ExerciseDetailView` gets its dark pass in a later step. All timer
/// behaviour stays in `RestTimerController`; this view only renders and forwards
/// taps, so the logic underneath is untouched.
///
/// Kept the type name `ExerciseRestTimerBar` so the single call site in
/// `exerciseBottomInset` doesn't change while the presentation is swapped.
struct ExerciseRestTimerBar: View {
    @Bindable var controller: RestTimerController
    /// The working-set number the user is resting *before*, e.g. 3 → "SET 3
    /// NEXT". nil hides the hint.
    var nextSetNumber: Int?
    /// The engine's suggestion for that next set, surfaced as the coaching line.
    var suggestion: SuggestedSet?

    /// Green while there's time, shifting to strain in the last 10 seconds —
    /// preserving the existing bar's "rest almost over" cue rather than dropping
    /// it for a single flat accent.
    private var accent: Color {
        controller.restRemaining <= 10 ? AppTheme.Dark.Signal.strain : AppTheme.Dark.Signal.recovery
    }

    var body: some View {
        VStack(spacing: 16) {
            RestTimerRing(
                remaining: controller.restRemaining,
                total: max(controller.restDuration, controller.restRemaining),
                accent: accent,
                nextHint: nextSetNumber.map { "SET \($0) NEXT" }
            )

            if let nudge = nudgeText {
                nudgeCard(nudge)
            }

            controls
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity)
        .background(AppTheme.Dark.surface)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 22, topTrailingRadius: 22, style: .continuous))
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Dark.hairline)
                .frame(height: 1)
        }
        .environment(\.colorScheme, .dark)
        .shadow(color: .black.opacity(0.4), radius: 20, y: -6)
        .transition(.move(edge: .bottom))
    }

    /// The next-set coaching line — the engine's own reasoning, never invented.
    private var nudgeText: String? {
        guard let suggestion, !suggestion.reasoning.isEmpty else { return nil }
        return suggestion.reasoning
    }

    private func nudgeCard(_ text: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(accent)
            Text(text)
                .font(.system(size: 12.5))
                .foregroundStyle(AppTheme.Dark.text)
                .lineSpacing(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(accent.opacity(0.27), lineWidth: 1)
        )
        .accessibilityLabel("Coaching: \(text)")
    }

    private var controls: some View {
        HStack(spacing: 10) {
            adjustButton("−15s", amount: -15, label: "Subtract 15 seconds")
            adjustButton("+15s", amount: 15, label: "Add 15 seconds")
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                controller.stop()
            } label: {
                Text("Skip rest")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.Dark.text2)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(AppTheme.Dark.surfaceHi, in: Capsule())
                    .overlay(Capsule().strokeBorder(AppTheme.Dark.hairline, lineWidth: 1))
            }
            .buttonStyle(.pressableCard)
            .accessibilityLabel("Skip rest timer")
        }
    }

    private func adjustButton(_ title: String, amount: Int, label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            controller.adjust(by: amount)
        } label: {
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .foregroundStyle(AppTheme.Dark.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(AppTheme.Dark.surfaceHi, in: Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.Dark.hairline, lineWidth: 1))
        }
        .buttonStyle(.pressableCard)
        .accessibilityLabel(label)
    }
}
