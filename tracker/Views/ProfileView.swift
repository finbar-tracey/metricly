import SwiftUI
import SwiftData

/// "You" (design_handoff_app, screen-profile.jsx) — the app's model of the
/// person, not a settings dump. Avatar and learned baselines up top; the goal,
/// connections, and a link into detailed settings below.
///
/// Editing still lives in the existing screens — the CONNECTED and SETTINGS
/// rows push to them — so this dashboard adds a view without duplicating the
/// forms.
struct ProfileView: View {
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.appServices) private var appServices

    @Query private var settingsArray: [UserSettings]
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var bodyWeights: [BodyWeightEntry]
    @Query private var liftGoals: [LiftGoal]

    @State private var hrv: [Double] = []
    @State private var rhr: [Double] = []
    @State private var sleepMinutes: Double?

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var healthKitEnabled: Bool { settings.healthKitEnabled }

    private var data: ProfileData {
        ProfileData.build(
            settings: settings,
            finishedWorkouts: finishedWorkouts,
            bodyWeights: bodyWeights,
            liftGoals: liftGoals,
            appleHealthLinked: healthKitEnabled,
            stravaLinked: appServices.strava.isConnected
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                identity
                baselines
                if let goal = data.goal {
                    goalCard(goal)
                }
                connected
                settingsCard
            }
            .padding(.bottom, 28)
        }
        .background(AppTheme.Dark.bg.ignoresSafeArea())
        .environment(\.colorScheme, .dark)
        .navigationTitle("You")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppTheme.Dark.bg, for: .navigationBar)
        .task {
            guard healthKitEnabled else { return }
            let hk = appServices.healthDataCache
            if hrv.isEmpty, let series = try? await hk.fetchDailyHRV(days: 7) {
                hrv = series.map(\.ms)
            }
            if rhr.isEmpty, let series = try? await hk.fetchDailyRestingHeartRate(days: 7) {
                rhr = series.map(\.bpm)
            }
            if sleepMinutes == nil, let sleep = try? await hk.fetchSleep(for: .now), sleep.totalMinutes > 0 {
                sleepMinutes = sleep.totalMinutes
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Spacer()
            if let since = data.memberSince {
                Text(since)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(AppTheme.Dark.text3)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
    }

    // MARK: - Identity

    private var identity: some View {
        HStack(spacing: 14) {
            Text(data.initial)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.Dark.text)
                .frame(width: 56, height: 56)
                .background(
                    Circle().fill(AppTheme.Dark.surfaceHi)
                        .overlay(
                            Circle().fill(
                                RadialGradient(
                                    colors: [AppTheme.Dark.Signal.recovery.opacity(0.27), .clear],
                                    center: .init(x: 0.3, y: 0.25), startRadius: 0, endRadius: 40
                                )
                            )
                        )
                )
                .overlay(Circle().strokeBorder(AppTheme.Dark.hairline, lineWidth: 1))
            VStack(alignment: .leading, spacing: 4) {
                Text(data.name)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(AppTheme.Dark.text)
                Text(data.statLine)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(0.6)
                    .foregroundStyle(AppTheme.Dark.text3)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Baselines

    private var baselines: some View {
        section(title: "YOUR BASELINES", right: "LEARNED · NOT GUESSED") {
            VStack(spacing: 0) {
                if healthKitEnabled, hrv.count >= 2 || rhr.count >= 2 {
                    if hrv.count >= 2 {
                        baselineRow("HRV BASELINE", value: "\(Int(average(hrv))) ms",
                                    series: hrv, tone: AppTheme.Dark.Signal.recovery, isLast: rhr.count < 2 && sleepMinutes == nil)
                    }
                    if rhr.count >= 2 {
                        baselineRow("RESTING HR", value: "\(Int(average(rhr))) bpm",
                                    series: rhr, tone: AppTheme.Dark.Signal.recovery, isLast: sleepMinutes == nil)
                    }
                    if let sleepMinutes {
                        baselineRow("SLEEP", value: HealthFormatters.formatSleepShort(sleepMinutes),
                                    series: [], tone: AppTheme.Dark.Signal.calm, isLast: true)
                    }
                } else {
                    baselineEmpty
                }
            }
            .darkCard(radius: 16)
        }
    }

    private func baselineRow(_ label: String, value: String, series: [Double], tone: Color, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(AppTheme.Dark.text4)
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.Dark.text)
            }
            Spacer()
            if series.count >= 2 {
                Sparkline(values: series, color: tone)
                    .frame(width: 64, height: 20)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppTheme.Dark.hairlineSoft).frame(height: 0.5).padding(.leading, 14)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private var baselineEmpty: some View {
        HStack(spacing: 10) {
            Image(systemName: healthKitEnabled ? "waveform.path.ecg" : "heart.text.square")
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.Dark.text3)
            Text(healthKitEnabled
                 ? "Learning your baselines — a few days of Health data and they'll appear."
                 : "Connect Apple Health and the engine learns your HRV, resting HR, and sleep.")
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.Dark.text2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    // MARK: - Goal

    private func goalCard(_ goal: ProfileData.GoalProgress) -> some View {
        let pct = Int((goal.fraction * 100).rounded())
        return section(title: "GOAL", right: "\(pct)% THERE") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(goal.exerciseName) \(weightUnit.formatShort(goal.targetKg))")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(-0.2)
                        .foregroundStyle(AppTheme.Dark.text)
                    Spacer()
                    Text("\(weightUnit.formatShort(goal.currentKg)) / \(weightUnit.formatShort(goal.targetKg))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.Dark.Signal.recovery)
                }
                ProgressTrack(fraction: goal.fraction, color: AppTheme.Dark.Signal.recovery)
                    .frame(height: 7)
                Text(paceText(goal))
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.Dark.text3)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 13)
            .darkCard(radius: 16, border: AppTheme.Dark.Signal.recovery.opacity(0.3))
        }
    }

    private func paceText(_ goal: ProfileData.GoalProgress) -> String {
        if let weeks = goal.etaWeeks {
            return "ON PACE · EST. \(weeks) WEEK\(weeks == 1 ? "" : "S") AT CURRENT PROGRESSION"
        }
        return "KEEP LOGGING · PACE APPEARS ONCE YOU'RE PROGRESSING"
    }

    // MARK: - Connected

    private var connected: some View {
        section(title: "CONNECTED", right: nil) {
            VStack(spacing: 0) {
                NavigationLink { HealthDashboardView() } label: {
                    connectedRow("Apple Health",
                                 status: data.appleHealthLinked ? "LINKED" : "CONNECT",
                                 tone: data.appleHealthLinked ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.text4,
                                 isLast: false)
                }
                .buttonStyle(.plain)
                NavigationLink { SettingsView() } label: {
                    connectedRow("Strava",
                                 status: data.stravaLinked ? "LINKED" : "ADD",
                                 tone: data.stravaLinked ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.text4,
                                 isLast: true)
                }
                .buttonStyle(.plain)
            }
            .darkCard(radius: 16)
        }
    }

    private func connectedRow(_ label: String, status: String, tone: Color, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(AppTheme.Dark.text)
            Spacer()
            Text(status)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(0.4)
                .foregroundStyle(tone)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Dark.text4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppTheme.Dark.hairlineSoft).frame(height: 0.5).padding(.leading, 14)
            }
        }
    }

    // MARK: - Settings

    private var settingsCard: some View {
        section(title: "SETTINGS", right: nil) {
            VStack(spacing: 0) {
                NavigationLink { ProfileSettingsView() } label: {
                    settingsRow("Units", value: data.unitLabel, isLast: false)
                }
                .buttonStyle(.plain)
                NavigationLink { SettingsView() } label: {
                    settingsRow("Notifications, export & more", value: "", isLast: true)
                }
                .buttonStyle(.plain)
            }
            .darkCard(radius: 16)
        }
    }

    private func settingsRow(_ label: String, value: String, isLast: Bool) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(AppTheme.Dark.text)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(0.4)
                    .foregroundStyle(AppTheme.Dark.text2)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.Dark.text4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(AppTheme.Dark.hairlineSoft).frame(height: 0.5).padding(.leading, 14)
            }
        }
    }

    // MARK: - Helpers

    private func average(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    @ViewBuilder
    private func section<Content: View>(
        title: String,
        right: String?,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundStyle(AppTheme.Dark.text3)
                Spacer()
                if let right {
                    Text(right)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .tracking(0.6)
                        .foregroundStyle(AppTheme.Dark.text4)
                }
            }
            content()
        }
        .padding(.horizontal, 18)
        .padding(.top, 20)
    }
}

/// A tiny static sparkline for the baseline rows.
private struct Sparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        GeometryReader { geo in
            Path { path in
                guard values.count > 1 else { return }
                let lo = values.min() ?? 0
                let hi = values.max() ?? 1
                let span = max(0.0001, hi - lo)
                let points = values.enumerated().map { index, value in
                    CGPoint(
                        x: CGFloat(index) / CGFloat(values.count - 1) * geo.size.width,
                        y: geo.size.height - 2 - CGFloat((value - lo) / span) * (geo.size.height - 4)
                    )
                }
                path.move(to: points[0])
                points.dropFirst().forEach { path.addLine(to: $0) }
            }
            .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .accessibilityHidden(true)
    }
}

/// The goal progress bar in the dark language.
private struct ProgressTrack: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.Dark.surfaceHi)
                Capsule()
                    .fill(color)
                    .frame(width: max(4, geo.size.width * min(1, max(0, fraction))))
                    .signalGlow(color, radius: 4, opacity: 0.4)
            }
        }
    }
}
