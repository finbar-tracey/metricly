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

    // MARK: - Page 2: Features

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
                featureRow(icon: "heart.fill", color: .red, title: "Health Integration", subtitle: "Connect with Apple Health for full insights")
            }
            .padding(.horizontal)

            Spacer()
            nextButton
        }
        .padding(32)
    }

    // MARK: - Page 3: Profile Setup

    private var profilePage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.accent)

            Text("Set Up Your Profile")
                .font(.title.bold())

            Text("Personalize your experience. You can change these anytime in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 16) {
                // Name
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    TextField("Your name (optional)", text: $userName)
                        .textContentType(.givenName)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                // Units
                HStack(spacing: 12) {
                    Image(systemName: "scalemass.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("Weight Unit")
                    Spacer()
                    Picker("", selection: $useKilograms) {
                        Text("kg").tag(true)
                        Text("lbs").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                // Weekly Goal
                HStack(spacing: 12) {
                    Image(systemName: "target")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("Weekly Goal")
                    Spacer()
                    Stepper("\(weeklyGoal) workouts", value: $weeklyGoal, in: 1...7)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))

                // Water Goal
                HStack(spacing: 12) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                    Text("Water Goal")
                    Spacer()
                    Stepper("\(dailyWaterGoalMl) ml", value: $dailyWaterGoalMl, in: 1000...5000, step: 250)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()
            nextButton
        }
        .padding(32)
    }

    // MARK: - Page 4: HealthKit

    private var healthPage: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundStyle(.red)

            Text("Connect Apple Health")
                .font(.title.bold())

            Text("Sync your steps, sleep, heart rate, and HRV for recovery insights and health tracking.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 14) {
                healthFeatureRow(icon: "figure.walk", color: .green, text: "Daily steps & active calories")
                healthFeatureRow(icon: "bed.double.fill", color: .indigo, text: "Sleep duration & quality")
                healthFeatureRow(icon: "heart.fill", color: .red, text: "Resting heart rate trends")
                healthFeatureRow(icon: "waveform.path.ecg", color: .purple, text: "HRV for recovery scoring")
            }
            .padding(.horizontal)

            Spacer()

            if healthKitRequested {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Health access requested")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.green)
                }
                .padding(.bottom, 8)
                nextButton
            } else {
                Button {
                    Task {
                        do {
                            try await HealthKitManager.shared.requestAuthorization()
                            settings.healthKitEnabled = true
                        } catch {
                            // User denied or HealthKit unavailable
                        }
                        healthKitRequested = true
                    }
                } label: {
                    HStack {
                        Image(systemName: "heart.fill")
                        Text("Connect Apple Health")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Button {
                    healthKitRequested = true
                    withAnimation {
                        currentPage = 4
                    }
                } label: {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(32)
    }

    // MARK: - Page 5: Get Started

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
                applySettings()
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

    // MARK: - Helpers

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

    private func healthFeatureRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.subheadline)
        }
    }

    private func applySettings() {
        let s = settings
        if !userName.isEmpty {
            s.userName = userName
        }
        s.useKilograms = useKilograms
        s.weeklyGoal = weeklyGoal
        s.dailyWaterGoalMl = dailyWaterGoalMl
    }
}
