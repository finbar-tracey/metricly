import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var settingsArray: [UserSettings]
    let onComplete: () -> Void

    @State private var currentPage = 0
    @State private var userName = ""
    @State private var useKilograms = true
    @State private var weeklyGoal = 3
    @State private var dailyWaterGoalMl = 2500
    @State private var healthKitRequested = false
    @State private var showingImport = false
    @State private var pendingImportPreview: ImportHelper.ImportPreview?
    @State private var pendingImportSuccess: OnboardingImportSuccess?
    @State private var importErrorMessage: String?

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomePage { advancePage() }
                .tag(0)
            OnboardingFeaturesPage { advancePage() }
                .tag(1)
            OnboardingAdaptivePage { advancePage() }
                .tag(2)
            OnboardingProfilePage(
                userName: $userName,
                useKilograms: $useKilograms,
                weeklyGoal: $weeklyGoal,
                dailyWaterGoalMl: $dailyWaterGoalMl,
                onContinue: advancePage
            )
            .tag(3)
            OnboardingHealthPage(
                healthKitRequested: $healthKitRequested,
                currentPage: $currentPage,
                settings: settings,
                onContinue: advancePage
            )
            .tag(4)
            OnboardingGetStartedPage(
                showingImport: $showingImport,
                pendingImportPreview: $pendingImportPreview,
                pendingImportSuccess: $pendingImportSuccess,
                importErrorMessage: $importErrorMessage,
                onApplySettings: applySettings,
                onComplete: onComplete,
                onFinishWithImport: finishWithImport
            )
            .tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .interactiveDismissDisabled()
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .overlay(alignment: .top) {
            progressBar
                .padding(.top, 60)
        }
        .overlay(alignment: .topTrailing) {
            if currentPage > 0 && currentPage < 5 {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation { currentPage = 5 }
                } label: {
                    Text("Skip")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.8), in: Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                }
                .buttonStyle(.pressableCard)
                .padding(.top, 56)
                .padding(.trailing, 16)
                .transition(.opacity)
            }
        }
    }

    private var progressBar: some View {
        let onGradient = currentPage == 0 || currentPage == 4 || currentPage == 5
        return HStack(spacing: 6) {
            ForEach(0..<6, id: \.self) { i in
                Capsule()
                    .fill(
                        i == currentPage
                            ? (onGradient ? Color.white : Color.accentColor)
                            : (onGradient ? Color.white.opacity(0.35) : Color.secondary.opacity(0.28))
                    )
                    .frame(width: i == currentPage ? 22 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
    }

    private func advancePage() {
        withAnimation { currentPage += 1 }
    }

    private func finishWithImport(workoutCount: Int) {
        applySettings()
        onComplete()
        dismiss()
    }

    private func applySettings() {
        let s = settings
        if !userName.isEmpty { s.userName = userName }
        s.useKilograms = useKilograms
        s.weeklyGoal = weeklyGoal
        s.dailyWaterGoalMl = dailyWaterGoalMl
    }
}
