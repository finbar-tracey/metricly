import SwiftUI

// MARK: - Dark palette (signals-glow)
//
// The palette itself lives in `DesignTokens/MetriclyTokens.swift` so the widget
// extension shares one definition with the app. This file is the app-side
// surface: the `AppTheme.Dark` spelling everything already uses, plus the
// chrome and motion helpers that depend on the app's view layer.
//
// Scoped to Home for now. Other tabs stay on the adaptive light/dark styling
// driven by the Settings appearance toggle; they get their own designs in later
// steps of the migration.
extension AppTheme {
    typealias Dark = MetriclyDark
}

extension MetriclyDark {

    /// The single source of truth for "what color is today?".
    ///
    /// Every accent on the redesigned Home — hero border and wash, pill, the
    /// verdict's second line, today's tape bar, the Start CTA — derives from
    /// this, so the screen reads as one decision rather than five widgets that
    /// happen to agree.
    static func accent(for intensity: TodayPlan.Intensity) -> Color {
        switch intensity {
        case .rest:     return Signal.calm
        case .light:    return Signal.focus
        case .moderate: return Signal.caution
        case .hard:     return Signal.recovery
        }
    }

    /// Signature motion for the redesign. The prototype's shared curve is
    /// `cubic-bezier(0.2, 0.8, 0.2, 1)`, which `.snappy` matches closely.
    enum Motion {
        /// Effort-tape bars growing in from the baseline.
        static let tapeGrowIn = Animation.snappy(duration: 0.7)
        /// Per-bar stagger for the tape, in seconds.
        static let tapeStagger: Double = 0.045
    }
}

// MARK: - Dark surface chrome

extension View {
    /// Card chrome for the dark surfaces: fill, continuous corner, hairline.
    /// Replaces the four-modifier stack that would otherwise be copied into
    /// every component in the redesign.
    func darkCard(radius: CGFloat = AppTheme.Dark.Radius.card,
                  fill: Color = AppTheme.Dark.surface,
                  border: Color = AppTheme.Dark.hairline) -> some View {
        background(fill)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }

    /// Inset-well chrome — a recess rather than a raised card. Used for the
    /// micro-signal row inside the hero.
    func darkWell(radius: CGFloat = AppTheme.Dark.Radius.well) -> some View {
        darkCard(radius: radius, fill: AppTheme.Dark.surfaceLo)
    }
}

// MARK: - Motion

extension View {
    /// Scales in from an edge on first appear — the tape / volume / muscle-load
    /// bar grow-in. `axis` picks vertical (bars rising) or horizontal (bars
    /// extending), matching the prototype's `scaleY` / `scaleX`.
    func growIn(
        axis: Axis = .vertical,
        animation: Animation = AppTheme.Dark.Motion.tapeGrowIn,
        delay: Double = 0
    ) -> some View {
        modifier(GrowIn(axis: axis, animation: animation, delay: delay))
    }
}

/// One-shot entrance scale, fired on appear and never again.
///
/// Reduce Motion skips the animation but *keeps the final state* — a tape that
/// never grew in is still a tape; a tape stuck at zero height is a bug.
private struct GrowIn: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    let axis: Axis
    let animation: Animation
    let delay: Double

    func body(content: Content) -> some View {
        let done = grown || reduceMotion
        return content
            .scaleEffect(
                x: axis == .horizontal ? (done ? 1 : 0) : 1,
                y: axis == .vertical ? (done ? 1 : 0) : 1,
                anchor: axis == .vertical ? .bottom : .leading
            )
            .onAppear {
                guard !reduceMotion, !grown else { return }
                withAnimation(animation.delay(delay)) { grown = true }
            }
    }
}
