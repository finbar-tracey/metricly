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
