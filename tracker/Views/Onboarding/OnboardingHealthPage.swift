import SwiftUI

struct OnboardingHealthPage: View {
    @Environment(\.appServices) private var appServices
    @Binding var healthKitRequested: Bool
    @Binding var currentPage: Int
    let settings: UserSettings
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: AppTheme.Gradients.strain,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 80, y: -30)

                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white)
                        Text("Connect Apple Health")
                            .font(.title2.bold())
                            .foregroundStyle(.white)
                        Text("Sync your activity data for deeper insights.")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
                .frame(minHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius))
                .padding(.horizontal)

                VStack(spacing: 10) {
                    healthBenefitRow(icon: "figure.walk", color: .green, text: "Daily steps & active calories")
                    healthBenefitRow(icon: "bed.double.fill", color: .indigo, text: "Sleep duration & quality")
                    healthBenefitRow(icon: "heart.fill", color: .red, text: "Resting heart rate trends")
                    healthBenefitRow(icon: "waveform.path.ecg", color: .purple, text: "HRV for recovery scoring")
                }
                .padding(.horizontal)

                Spacer()

                if healthKitRequested {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("Health access requested")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    OnboardingPageStyle.continueButton(action: onContinue)
                } else {
                    VStack(spacing: 14) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                do {
                                    try await appServices.healthKit.requestAuthorization()
                                    settings.healthKitEnabled = true
                                } catch { }
                                healthKitRequested = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("Connect Apple Health")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .tracking(0.4)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: AppTheme.Gradients.strain,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                                    .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
                            )
                            .shadow(color: AppTheme.Signal.strain.opacity(0.45), radius: 14, y: 6)
                        }
                        .buttonStyle(.pressableCard)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            healthKitRequested = true
                            withAnimation { currentPage = 5 }
                        } label: {
                            Text("Skip for now")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .tracking(0.3)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
            }
            .padding(32)
        }
    }

    private func healthBenefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            OnboardingPageStyle.gradientIconDisc(icon, color: color, size: 38, glyph: 15)
            Text(text).font(.subheadline)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(color.opacity(0.6))
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}
