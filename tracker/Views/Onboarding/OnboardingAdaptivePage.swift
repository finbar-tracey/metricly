import SwiftUI

struct OnboardingAdaptivePage: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingPageStyle.interiorBackground(.purple)

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                VStack(spacing: 6) {
                    Text(String(localized: "It gets smarter as you go", comment: "Onboarding adaptive-coach page title"))
                        .font(.title.bold())
                    Text(String(localized: "Four signals reshape today's plan.", comment: "Onboarding adaptive-coach page subtitle"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    adaptiveStep(
                        icon: "figure.cooldown",
                        color: .purple,
                        title: String(localized: "Tell it how you feel", comment: "Onboarding card title — soreness self-report"),
                        subtitle: String(localized: "After each workout, mark any muscles that are sore. Your input wins over the model when they disagree.", comment: "Onboarding card subtitle — soreness self-report")
                    )
                    adaptiveStep(
                        icon: "checkmark.seal.fill",
                        color: .green,
                        title: String(localized: "It watches whether you listen", comment: "Onboarding card title — trust calibration"),
                        subtitle: String(localized: "If you reliably train through suggested rest days, the engine notices and adjusts its confidence — and how loudly it suggests rest next time.", comment: "Onboarding card subtitle — trust calibration")
                    )
                    adaptiveStep(
                        icon: "calendar.badge.clock",
                        color: AppTheme.Signal.strain,
                        title: String(localized: "Multi-week training blocks", comment: "Onboarding card title — training blocks"),
                        subtitle: String(localized: "Run a 4-week build / 1-week deload rhythm. Metricly caps intensity during deload weeks so cumulative fatigue clears, and shows whether your blocks are actually paying off.", comment: "Onboarding card subtitle — training blocks")
                    )
                    adaptiveStep(
                        icon: "chart.line.uptrend.xyaxis",
                        color: .blue,
                        title: String(localized: "Patterns surface over time", comment: "Onboarding card title — patterns"),
                        subtitle: String(localized: "After ~90 days the Insights tab starts naming patterns the engine spotted in your data — sleep × performance, body weight × strength, and more.", comment: "Onboarding card subtitle — patterns")
                    )
                }
                .padding(.horizontal)

                Spacer()
                OnboardingPageStyle.continueButton(action: onContinue)
            }
            .padding(32)
        }
    }

    /// Tile used by the adaptive-coach page. Similar to `howItWorksStep`
    /// but without the numbered badge — these are concurrent signals,
    /// not sequential steps.
    private func adaptiveStep(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            OnboardingPageStyle.gradientIconDisc(icon, color: color)

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
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius))
    }
}
