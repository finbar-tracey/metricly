import SwiftUI
import UIKit

// MARK: - PressableCardStyle
// Subtle scale + light haptic when a card-shaped Button is pressed.
// Apply with `.buttonStyle(.pressableCard)`.
//
// SAFE: no TimelineView, no repeatForever animations. Animation only fires
// in response to user touch, never on appear / on its own.

struct PressableCardStyle: ButtonStyle {
    var scale: CGFloat = 0.94
    var haptic: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.05 : 0)
            .animation(AppTheme.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed && haptic {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
    }
}

extension ButtonStyle where Self == PressableCardStyle {
    static var pressableCard: PressableCardStyle { PressableCardStyle() }
    static func pressableCard(scale: CGFloat = 0.94, haptic: Bool = true) -> PressableCardStyle {
        PressableCardStyle(scale: scale, haptic: haptic)
    }
}

// MARK: - AnimatedInt / AnimatedNumber
// Smooth numeric tween via Apple's contentTransition(.numericText).
//
// SAFE: pure Apple-supplied animation primitive. No timers, no recursion,
// no infinite repeat. The animation only fires when `value` changes.

struct AnimatedInt: View {
    let value: Int
    var font: Font = .system(size: 52, weight: .black, design: .rounded)
    var color: Color = .primary

    var body: some View {
        Text("\(value)")
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: Double(value)))
            .animation(AppTheme.Motion.numeric, value: value)
    }
}

struct AnimatedNumber: View {
    let value: Double
    var format: String = "%.0f"
    var font: Font = .system(size: 52, weight: .black, design: .rounded)
    var color: Color = .primary

    var body: some View {
        Text(String(format: format, value))
            .font(font)
            .foregroundStyle(color)
            .monospacedDigit()
            .contentTransition(.numericText(value: value))
            .animation(AppTheme.Motion.numeric, value: value)
    }
}

// MARK: - HeroCard
// The boilerplate that used to live in ~17 detail views: a diagonal
// gradient, a top sheen, two soft white blurred circles, and a rounded
// drop shadow. Identical structure across every site — only the palette
// and the content inside varied. Now: callers wrap their content with
// `HeroCard(palette:) { ... }` instead of pasting 10 lines of decoration.
//
// SAFE: pure static gradients + circles. No timers, animations, or
// recursion in the decoration itself; the inner content is whatever
// the caller provides.

struct HeroCard<Content: View>: View {
    let palette: [Color]
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: palette,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Top sheen
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            Circle().fill(.white.opacity(0.10))
                .frame(width: 220).blur(radius: 12)
                .offset(x: 160, y: -70)
            Circle().fill(.white.opacity(0.06))
                .frame(width: 110).blur(radius: 10)
                .offset(x: -30, y: 80)

            content()
        }
        .heroCard()
    }
}

// MARK: - GradientDisc
// The app-wide gradient icon disc — extracted from the copy-pasted
// `gradientDisc(...)` helpers (water/caffeine/creatine trackers) and the
// inline ZStacks. One source of truth, and colorScheme-aware: the fill /
// stroke opacities step up on dark so the disc pops on #1C1C1E.
//
// SAFE: pure static gradient + stroke. No timers/animations.

struct GradientDisc: View {
    let icon: String
    var color: Color
    var size: CGFloat = 40
    var glyph: CGFloat = 17
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let fillHi = scheme == .dark ? 0.30 : 0.26
        let fillLo = scheme == .dark ? 0.14 : 0.12
        let strokeO = scheme == .dark ? 0.36 : 0.30
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(fillHi), color.opacity(fillLo)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(Circle().stroke(color.opacity(strokeO), lineWidth: 0.5))
            Image(systemName: icon)
                .font(.system(size: glyph, weight: .semibold))
                .foregroundStyle(color)
        }
    }
}

/// Drop-in for the old per-view `gradientDisc(_:color:size:glyph:)` helpers.
/// Returns the shared `GradientDisc` view (colorScheme-aware).
func gradientDisc(_ icon: String, color: Color, size: CGFloat = 40, glyph: CGFloat = 17) -> GradientDisc {
    GradientDisc(icon: icon, color: color, size: size, glyph: glyph)
}

// MARK: - TintedCallout
// The category-tinted card chrome (wash + tinted border + shadow) used by
// the insight cards / tease card. Extracted from 3+ inline copies and made
// colorScheme-aware (wash & border step up on dark, where a 0.10 wash would
// otherwise vanish on the dark card surface).
//
// SAFE: pure static fills. No timers/animations.

struct TintedCallout: ViewModifier {
    let color: Color
    var radius: CGFloat = AppTheme.cardRadius
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let washO = scheme == .dark ? 0.14 : 0.10
        let borderO = scheme == .dark ? 0.26 : 0.20
        content
            .padding(16)
            .background(
                ZStack {
                    Color(.secondarySystemGroupedBackground)
                    LinearGradient(
                        colors: [color.opacity(washO), .clear],
                        startPoint: .topLeading, endPoint: .center
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(color.opacity(borderO), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }
}

extension View {
    /// Category-tinted callout card chrome (wash + tinted border + shadow).
    func tintedCallout(_ color: Color, radius: CGFloat = AppTheme.cardRadius) -> some View {
        modifier(TintedCallout(color: color, radius: radius))
    }
}

// MARK: - GradientCapsule (BadgePill chrome)
// The gradient-capsule background + hairline used by every tinted badge
// pill (insight strength badge, "PATTERN SPOTTED", intensity pill, …).
// Extracted from ~6 inline copies; leaves each badge's content as-is and
// just supplies the repeated chrome. colorScheme-aware.
//
// SAFE: pure static fill + stroke.

struct GradientCapsule: ViewModifier {
    let color: Color
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let hi = scheme == .dark ? 0.26 : 0.20
        let lo = scheme == .dark ? 0.14 : 0.10
        let strokeO = scheme == .dark ? 0.30 : 0.24
        content
            .background(
                LinearGradient(
                    colors: [color.opacity(hi), color.opacity(lo)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: Capsule()
            )
            .overlay(Capsule().stroke(color.opacity(strokeO), lineWidth: 0.5))
    }
}

extension View {
    /// Tinted gradient-capsule chrome for badge pills (`[color@0.20→0.10]` + hairline).
    func gradientCapsule(_ color: Color) -> some View {
        modifier(GradientCapsule(color: color))
    }
}

// MARK: - FilterChip
// Shared selectable chip — selected = gradient fill + colored shadow + white
// label; unselected = tinted fill + colored label. colorScheme-aware via the
// shared chrome. For NEW chip rows + the muscle/category filters.
//
// SAFE: pure static fills; press feedback via .pressableCard at the call site.

struct FilterChip: View {
    let label: String
    var icon: String? = nil
    var color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                if let icon {
                    Image(systemName: icon).font(.system(size: 11, weight: .bold))
                }
                Text(label).font(.system(size: 13, weight: .semibold, design: .rounded))
            }
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background {
                if isSelected {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: color.opacity(0.40), radius: 6, y: 3)
                } else {
                    Capsule().fill(color.opacity(0.12))
                }
            }
            .foregroundStyle(isSelected ? .white : color)
        }
        .buttonStyle(.pressableCard)
    }
}

// MARK: - TabBackground
// Soft top-fading gradient that gives each tab its own color identity.
// Layered above the system grouped background.
//
// SAFE: pure static gradient. No TimelineView, no animations, no GeometryReader.

struct TabBackground: ViewModifier {
    let tint: Color
    var height: CGFloat = 360
    var intensity: Double = 0.35

    func body(content: Content) -> some View {
        content
            .background {
                ZStack(alignment: .top) {
                    Color(.systemGroupedBackground)
                    LinearGradient(
                        colors: [tint.opacity(intensity), tint.opacity(intensity * 0.4), tint.opacity(0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: height)
                    .frame(maxWidth: .infinity)
                }
                .ignoresSafeArea()
            }
    }
}

extension View {
    func tabBackground(tint: Color, height: CGFloat = 360, intensity: Double = 0.35) -> some View {
        modifier(TabBackground(tint: tint, height: height, intensity: intensity))
    }
}
