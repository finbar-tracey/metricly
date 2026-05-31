import SwiftUI

struct OnboardingWelcomePage: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: AppTheme.Gradients.calm,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle().fill(.white.opacity(0.06)).frame(width: 320).offset(x: 120, y: -180)
            Circle().fill(.white.opacity(0.04)).frame(width: 200).offset(x: -100, y: 200)

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle().fill(.white.opacity(0.15)).frame(width: 130, height: 130)
                    Circle().fill(.white.opacity(0.10)).frame(width: 100, height: 100)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 12) {
                    Text("Train smarter\nevery day.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Metricly tells you what to train,\nhow hard to push, and why —\nbased on your recovery.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                OnboardingPageStyle.gradientContinueButton(
                    label: "Get Started",
                    color: .white,
                    textColor: .accentColor,
                    action: onContinue
                )
            }
            .padding(32)
        }
    }
}
