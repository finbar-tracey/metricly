import SwiftUI

struct OnboardingProfilePage: View {
    @Binding var userName: String
    @Binding var useKilograms: Bool
    @Binding var weeklyGoal: Int
    @Binding var dailyWaterGoalMl: Int
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            OnboardingPageStyle.interiorBackground(.accentColor)

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
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Weekly Goal")
                                    .font(.subheadline)
                                Text("\(weeklyGoal) workouts / week")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper("", value: $weeklyGoal, in: 1...7)
                                .labelsHidden()
                        }
                    }

                    profileField(icon: "drop.fill", color: .blue) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Daily Water Goal")
                                    .font(.subheadline)
                                Text("\(dailyWaterGoalMl) ml / day")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Stepper("", value: $dailyWaterGoalMl, in: 1000...5000, step: 250)
                                .labelsHidden()
                        }
                    }
                }

                Spacer()
                OnboardingPageStyle.continueButton(action: onContinue)
            }
            .padding(32)
        }
    }

    private func profileField<Content: View>(icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            OnboardingPageStyle.gradientIconDisc(icon, color: color, size: 34, glyph: 14)
            content()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
