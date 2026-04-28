import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var settingsArray: [UserSettings]
    let onComplete: () -> Void

    @State private var currentPage = 0

    // Profile fields
    @State private var userName = ""
    @State private var useKilograms = true
    @State private var weeklyGoal = 3
    @State private var dailyWaterGoalMl = 2500
    @State private var healthKitRequested = false

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            featuresPage.tag(1)
            profilePage.tag(2)
            healthPage.tag(3)
            getStartedPage.tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentColor, Color.blue.opacity(0.85)],
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

                VStack(spacing: 10) {
                    Text("Welcome to Metricly")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("Your simple, powerful gym companion.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                gradientNextButton(label: "Get Started", color: .white, textColor: .accentColor)
            }
            .padding(32)
        }
    }

    // MARK: - Page 2: Features

    private var featuresPage: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 6) {
                    Text("Everything You Need")
                        .font(.title.bold())
                    Text("Built for serious lifters and casual gym-goers alike.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    featureCard(icon: "plus.circle.fill", color: .accentColor, title: "Quick Logging", subtitle: "Add sets in seconds with smart defaults")
                    featureCard(icon: "clock.arrow.circlepath", color: .blue, title: "Auto-Fill", subtitle: "Pre-fills from your last session automatically")
                    featureCard(icon: "trophy.fill", color: .yellow, title: "PR Tracking", subtitle: "Celebrates every time you beat your best")
                    featureCard(icon: "chart.bar.fill", color: .green, title: "Volume Trends", subtitle: "See your weekly progress at a glance")
                    featureCard(icon: "heart.fill", color: .red, title: "Health Integration", subtitle: "Sync steps, sleep, and heart rate from Apple Health")
                }
                .padding(.horizontal)

                Spacer()
                nextButton
            }
            .padding(32)
        }
    }

    // MARK: - Page 3: Profile Setup

    private var profilePage: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 90, height: 90)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(spacing: 8) {
                    Text("Set Up Your Profile")
                        .font(.title.bold())
                    Text("Personalize your experience. You can change these anytime in Settings.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    profileField(icon: "person.fill", color: .accentColor) {
                        TextField("Your name (optional)", text: $userName)
                            .textContentType(.givenName)
                    }

                    profileField(icon: "scalemass.fill", color: .orange) {
                        HStack {
                            Text("Weight Unit")
                            Spacer()
                            Picker("", selection: $useKilograms) {
                                Text("kg").tag(true)
                                Text("lbs").tag(false)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }
                    }

                    profileField(icon: "target", color: .green) {
                        Stepper("\(weeklyGoal) workouts / week", value: $weeklyGoal, in: 1...7)
                    }

                    profileField(icon: "drop.fill", color: .blue) {
                        Stepper("\(dailyWaterGoalMl) ml / day", value: $dailyWaterGoalMl, in: 1000...5000, step: 250)
                    }
                }

                Spacer()
                nextButton
            }
            .padding(32)
        }
    }

    // MARK: - Page 4: HealthKit

    private var healthPage: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                ZStack(alignment: .bottom) {
                    LinearGradient(
                        colors: [.red, Color(red: 0.9, green: 0.2, blue: 0.3)],
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
                    nextButton
                } else {
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                do {
                                    try await HealthKitManager.shared.requestAuthorization()
                                    settings.healthKitEnabled = true
                                } catch { }
                                healthKitRequested = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "heart.fill")
                                Text("Connect Apple Health")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(LinearGradient(colors: [.red, Color(red: 0.85, green: 0.15, blue: 0.2)], startPoint: .leading, endPoint: .trailing))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .red.opacity(0.3), radius: 10, y: 4)
                        }
                        .buttonStyle(.plain)

                        Button {
                            healthKitRequested = true
                            withAnimation { currentPage = 4 }
                        } label: {
                            Text("Skip for now")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(32)
        }
    }

    // MARK: - Page 5: Get Started

    private var getStartedPage: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.68, blue: 0.4), Color(red: 0.0, green: 0.5, blue: 0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle().fill(.white.opacity(0.07)).frame(width: 280).offset(x: 100, y: -160)
            Circle().fill(.white.opacity(0.04)).frame(width: 160).offset(x: -80, y: 200)

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle().fill(.white.opacity(0.15)).frame(width: 130, height: 130)
                    Circle().fill(.white.opacity(0.10)).frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(spacing: 10) {
                    Text("You're All Set!")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Start by creating your first workout.\nTap + to get going.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }

                Spacer()

                gradientNextButton(label: "Start Training", color: .white, textColor: Color(red: 0.12, green: 0.68, blue: 0.4)) {
                    applySettings()
                    onComplete()
                    dismiss()
                }
            }
            .padding(32)
        }
    }

    // MARK: - Helpers

    private var nextButton: some View {
        Button {
            withAnimation { currentPage += 1 }
        } label: {
            Text("Continue")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func gradientNextButton(label: String, color: Color, textColor: Color, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action { action() } else { withAnimation { currentPage += 1 } }
        } label: {
            Text(label)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(color)
                .foregroundStyle(textColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private func featureCard(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.bold())
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func profileField<Content: View>(icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 14, weight: .semibold)).foregroundStyle(color)
            }
            content()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func healthBenefitRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: icon).font(.system(size: 15)).foregroundStyle(color)
            }
            Text(text).font(.subheadline)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(color.opacity(0.6))
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func applySettings() {
        let s = settings
        if !userName.isEmpty { s.userName = userName }
        s.useKilograms = useKilograms
        s.weeklyGoal = weeklyGoal
        s.dailyWaterGoalMl = dailyWaterGoalMl
    }
}
