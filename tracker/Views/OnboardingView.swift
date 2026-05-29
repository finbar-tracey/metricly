import SwiftUI
import SwiftData
import UniformTypeIdentifiers

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
    // Import-from-Strong/Hevy state on the Get Started page. Same
    // flow as Settings → Import: file picker → preview sheet →
    // confirm → wow-moment sheet. After the user sees the wow
    // sheet, onboarding completes the same way Start Fresh does.
    @State private var showingImport = false
    @State private var pendingImportPreview: ImportHelper.ImportPreview?
    @State private var pendingImportSuccess: OnboardingImportSuccess?
    @State private var importErrorMessage: String?

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var body: some View {
        TabView(selection: $currentPage) {
            welcomePage.tag(0)
            featuresPage.tag(1)
            adaptivePage.tag(2)
            profilePage.tag(3)
            healthPage.tag(4)
            getStartedPage.tag(5)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .interactiveDismissDisabled()
        // Onboarding is a chrome surface with hand-tuned hero compositions —
        // fixed-size SF Symbol glyphs (.system(size: 52)) inside fixed-size
        // Circles (width: 130) and multi-line copy that breaks visually at
        // accessibility text sizes. Clamping at xxLarge keeps the layout
        // recognisable for users on AX1–AX5 without rewriting every page
        // to use Dynamic-Type-aware fonts. The chrome remains readable —
        // xxLarge is two steps up from default — and the user can still
        // use AX sizes everywhere else in the app.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
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

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
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

                gradientNextButton(label: "Get Started", color: .white, textColor: .accentColor)
            }
            .padding(32)
        }
    }

    // MARK: - Page 2: How it works

    private var featuresPage: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

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
                nextButton
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
                    .fill(color.opacity(0.16))
                    .frame(width: 44, height: 44)
                VStack(spacing: -2) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(color)
                }
                // Step number badge in the top-right of the icon circle
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

    // MARK: - Page 3: Adaptive coach story
    //
    // Onboarding used to stop at "we'll show you a daily plan." That
    // misses the part that makes this app different — your reports
    // and your behaviour reshape the plan over time. This page tells
    // that story before profile setup so users know why the
    // soreness picker and the trust-calibration prompts exist later.

    private var adaptivePage: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer().frame(height: 20)

                VStack(spacing: 6) {
                    Text(String(localized: "It gets smarter as you go", comment: "Onboarding adaptive-coach page title"))
                        .font(.title.bold())
                    Text(String(localized: "Three signals reshape today's plan.", comment: "Onboarding adaptive-coach page subtitle"))
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
                        icon: "chart.line.uptrend.xyaxis",
                        color: .blue,
                        title: String(localized: "Patterns surface over time", comment: "Onboarding card title — patterns"),
                        subtitle: String(localized: "After ~90 days the Insights tab starts naming patterns the engine spotted in your data — sleep × performance, body weight × strength, and more.", comment: "Onboarding card subtitle — patterns")
                    )
                }
                .padding(.horizontal)

                Spacer()
                nextButton
            }
            .padding(32)
        }
    }

    /// Tile used by the adaptive-coach page. Similar to `howItWorksStep`
    /// but without the numbered badge — these are concurrent signals,
    /// not sequential steps.
    private func adaptiveStep(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(color)
            }

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

    // MARK: - Page 4: Profile Setup

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
                    VStack(spacing: 14) {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            Task {
                                do {
                                    try await HealthKitManager.shared.requestAuthorization()
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
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.white.opacity(0.20), lineWidth: 0.5)
                            )
                            .shadow(color: AppTheme.Signal.strain.opacity(0.45), radius: 14, y: 6)
                        }
                        .buttonStyle(.pressableCard)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            healthKitRequested = true
                            // Sprint 13 inserted the adaptivePage at tag 2 and
                            // renumbered everything after it. The HealthKit
                            // page is now tag 4; "Get Started" is tag 5. Skip
                            // must advance past health, not back to it.
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

    // MARK: - Page 5: Get Started

    private var getStartedPage: some View {
        ZStack {
            LinearGradient(
                colors: AppTheme.Gradients.recovery,
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
                    Text("You're all set.")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.white)
                    Text("Log your first workout —\nMetricly will start learning your\nrecovery patterns from day one.")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(spacing: 12) {
                    // Primary CTA — the reviewer's pitch: importing
                    // an existing Strong/Hevy history gives Metricly
                    // months of data to analyse before the user logs
                    // a single set. Tapping fires the same flow as
                    // Settings → Import.
                    Button {
                        showingImport = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "tray.and.arrow.down.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text("Import history (Strong / Hevy)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .tracking(0.3)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .foregroundStyle(Color(red: 0.12, green: 0.68, blue: 0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .shadow(color: .black.opacity(0.18), radius: 14, y: 6)
                    }
                    .buttonStyle(.pressableCard)

                    // Secondary — keep the existing "no history,
                    // start fresh" path for users with no Strong/Hevy
                    // export to bring across.
                    Button {
                        applySettings()
                        onComplete()
                        dismiss()
                    } label: {
                        Text("Start fresh")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .tracking(0.3)
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 22)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(32)
        }
        .fileImporter(
            isPresented: $showingImport,
            allowedContentTypes: [.commaSeparatedText, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                do {
                    switch try ImportHelper.plan(from: url) {
                    case .preview(let preview):
                        pendingImportPreview = preview
                    case .metriclyDirect:
                        // Re-importing your own Metricly export
                        // from an onboarding flow is unusual but
                        // legal — let it through, skipping the
                        // wow sheet since the user already knows
                        // what's in their export.
                        let count = try ImportHelper.importCSV(from: url, into: modelContext)
                        importErrorMessage = nil
                        finishWithImport(workoutCount: count)
                    }
                } catch {
                    importErrorMessage = error.localizedDescription
                }
            case .failure(let error):
                importErrorMessage = error.localizedDescription
            }
        }
        .sheet(item: $pendingImportPreview) { preview in
            ImportPreviewSheet(
                preview: preview,
                onImport: {
                    let count = ImportHelper.commitPreview(preview, into: modelContext)
                    pendingImportPreview = nil
                    if count > 0 {
                        let analysis = ImportAnalyzer.analyze(preview.workouts)
                        pendingImportSuccess = OnboardingImportSuccess(analysis: analysis)
                    } else {
                        finishWithImport(workoutCount: 0)
                    }
                },
                onCancel: {
                    pendingImportPreview = nil
                }
            )
        }
        .sheet(item: $pendingImportSuccess) { presentation in
            ImportSuccessSheet(
                analysis: presentation.analysis,
                onStartRecommended: {
                    pendingImportSuccess = nil
                    applySettings()
                    onComplete()
                    dismiss()
                    NotificationCenter.default.post(name: .openTrainingTab, object: nil)
                },
                onDismiss: {
                    pendingImportSuccess = nil
                    applySettings()
                    onComplete()
                    dismiss()
                }
            )
        }
        .alert("Import Failed",
               isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
               )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importErrorMessage ?? "")
        }
    }

    /// Common completion path used by the Metricly-direct fallback
    /// and the empty-import edge case. Same final state as the
    /// "Start fresh" button — onboarding closes, the user lands on
    /// Home with whatever data the import did (or didn't) land.
    private func finishWithImport(workoutCount: Int) {
        applySettings()
        onComplete()
        dismiss()
    }

    // MARK: - Helpers

    private var nextButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation { currentPage += 1 }
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

    private func gradientNextButton(label: String, color: Color, textColor: Color, action: (() -> Void)? = nil) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            if let action { action() } else { withAnimation { currentPage += 1 } }
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

/// Identifiable wrapper so SwiftUI's `sheet(item:)` can drive the
/// post-import success sheet from a freshly-computed `ImportAnalysis`
/// inside the onboarding flow. Mirrors the wrapper in SettingsView —
/// each surface keeps its own so the types don't have to be public.
private struct OnboardingImportSuccess: Identifiable {
    let id = UUID()
    let analysis: ImportAnalysis
}
