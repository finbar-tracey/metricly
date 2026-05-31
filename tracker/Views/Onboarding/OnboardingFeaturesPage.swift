import SwiftUI

struct OnboardingFeaturesPage: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingPageStyle.interiorBackground(.teal)

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                VStack(spacing: 6) {
                    Text("How it works")
                        .font(.title.bold())
                    Text("Four steps. Every day.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    howItWorksStep(
                        number: 1,
                        icon: "heart.text.square.fill",
                        color: .red,
                        title: "Connect Health",
                        subtitle: "Sleep, HRV, resting heart rate — feeds your readiness score"
                    )
                    howItWorksStep(
                        number: 2,
                        icon: "gauge.with.needle.fill",
                        color: .teal,
                        title: "Get your readiness",
                        subtitle: "A daily score showing how recovered each muscle group is"
                    )
                    howItWorksStep(
                        number: 3,
                        icon: "wand.and.stars",
                        color: .blue,
                        title: "Follow your adaptive plan",
                        subtitle: "Today's workout, intensity, and adjustments — explained"
                    )
                    howItWorksStep(
                        number: 4,
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green,
                        title: "Track progress automatically",
                        subtitle: "PRs, patterns and trends surface as you train"
                    )
                }
                .padding(.horizontal)

                Spacer()
                OnboardingPageStyle.continueButton(action: onContinue)
            }
            .padding(32)
        }
    }

    /// One row in the "How it works" sequence — circled step number, icon,
    /// title and subtitle. Designed to be quickly scannable.
    private func howItWorksStep(number: Int, icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.26), color.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(color.opacity(0.28), lineWidth: 0.5))
                VStack(spacing: -2) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text("\(number)")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 18, height: 18)
                    .background(color, in: Circle())
                    .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                    .offset(x: 16, y: -14)
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

enum OnboardingPageStyle {
    static func interiorBackground(_ accent: Color) -> some View {
        ZStack {
            Color(.systemGroupedBackground)
            LinearGradient(
                colors: [accent.opacity(0.10), .clear],
                startPoint: .top, endPoint: .center
            )
            Circle()
                .fill(accent.opacity(0.06))
                .frame(width: 300)
                .blur(radius: 12)
                .offset(x: 130, y: -210)
        }
        .ignoresSafeArea()
    }

    static func gradientIconDisc(_ icon: String, color: Color, size: CGFloat = 44, glyph: CGFloat = 18) -> some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.26), color.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(Circle().stroke(color.opacity(0.28), lineWidth: 0.5))
            Image(systemName: icon)
                .font(.system(size: glyph, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    static func continueButton(action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(0.4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
            )
            .shadow(color: Color.accentColor.opacity(0.45), radius: 14, y: 6)
        }
        .buttonStyle(.pressableCard)
    }

    static func gradientContinueButton(
        label: String,
        color: Color,
        textColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .tracking(0.4)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [color, color.opacity(0.86)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .foregroundStyle(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.30), lineWidth: 0.5)
            )
            .shadow(color: textColor.opacity(0.18), radius: 14, y: 6)
        }
        .buttonStyle(.pressableCard)
    }
}
