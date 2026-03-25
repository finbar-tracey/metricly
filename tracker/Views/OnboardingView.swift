import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    let onComplete: () -> Void

    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            featuresPage.tag(1)
            getStartedPage.tag(2)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    private var welcomePage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 80))
                .foregroundStyle(.accent)
            Text("Welcome to Metricly")
                .font(.largeTitle.bold())
            Text("Your simple, powerful gym companion.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            nextButton
        }
        .padding(32)
    }

    private var featuresPage: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("Everything You Need")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: 20) {
                featureRow(icon: "plus.circle.fill", color: .accentColor, title: "Quick Logging", subtitle: "Add sets in seconds with smart defaults")
                featureRow(icon: "clock.arrow.circlepath", color: .blue, title: "Auto-Fill", subtitle: "Pre-fills from your last session")
                featureRow(icon: "star.fill", color: .yellow, title: "PR Tracking", subtitle: "Celebrates when you beat your best")
                featureRow(icon: "chart.bar.fill", color: .green, title: "Volume Charts", subtitle: "See your weekly progress at a glance")
                featureRow(icon: "timer", color: .orange, title: "Rest Timer", subtitle: "Stay on track between sets")
            }
            .padding(.horizontal)

            Spacer()
            nextButton
        }
        .padding(32)
    }

    private var getStartedPage: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("You're All Set")
                .font(.largeTitle.bold())
            Text("Start by creating your first workout.\nTap + to get going.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                onComplete()
                dismiss()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }

    private var nextButton: some View {
        Button {
            withAnimation {
                currentPage += 1
            }
        } label: {
            Text("Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.borderedProminent)
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
