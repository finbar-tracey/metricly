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
