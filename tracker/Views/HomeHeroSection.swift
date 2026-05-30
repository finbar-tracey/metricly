import SwiftUI

/// The top hero card on the home dashboard. Renders the recovery
/// readiness score as a large centered ring with the three input
/// signals (HRV · Sleep · Resting HR) beneath it, or a streak fallback
/// when HealthKit is off / data hasn't loaded yet. Includes the week
/// activity strip at the bottom.
///
/// Design: ring-centric ("Direction B"). The score is the unmistakable
/// hero, and the signals that *drive* it are surfaced directly so the
/// number is explainable rather than opaque. The old suggestion chip
/// was removed — it duplicated the adaptive plan card immediately below
/// this hero, which owns "today's recommendation" and its Start CTA.
///
/// Decoration note: uses a custom ZStack instead of the shared `HeroCard`
/// because the second circle sits on the right (not left) and the
/// gradient fades in on `healthDataLoaded`. Pulling those quirks into
/// the shared component would broaden its API past usefulness.
struct HomeHeroSection: View {
    let greeting: String
    let healthKitEnabled: Bool
    let healthDataLoaded: Bool
    let recovery: RecoveryResult
    let hrv: Double?
    let sleepMinutes: Double
    let restingHR: Double?
    let currentStreak: Int
    let allWorkouts: [Workout]
    let animateRings: Bool
    let gradientColors: [Color]
    let onWeekDayTapped: (Workout) -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
                .animation(.easeInOut(duration: 0.6), value: healthDataLoaded)
            // Top sheen for depth
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            Circle().fill(.white.opacity(0.10)).frame(width: 220).blur(radius: 12).offset(x: 180, y: -70)
            Circle().fill(.white.opacity(0.06)).frame(width: 140).blur(radius: 10).offset(x: 260, y: 60)

            VStack(alignment: .leading, spacing: 16) {
                // Greeting
                Text(greeting)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)

                if healthKitEnabled && healthDataLoaded {
                    readinessReadout
                } else {
                    streakFallback
                }

                // Hairline separating the readout from the week strip.
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 1)

                weekActivityStrip
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Readiness readout (ring + signals)

    private var readinessReadout: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Recovery Readiness")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .tracking(0.5)
                .textCase(.uppercase)

            readinessRing
                .frame(maxWidth: .infinity)

            signalStrip
        }
    }

    /// Large centered ring whose arc encodes the readiness score, with
    /// the percentage and short label stacked inside.
    private var readinessRing: some View {
        let progress = CGFloat(recovery.readinessScore)
        return ZStack {
            Circle()
                .stroke(.white.opacity(0.20), lineWidth: 13)
                .frame(width: 172, height: 172)
            Circle()
                .trim(from: 0, to: animateRings ? progress : 0)
                .stroke(readinessTintColor, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 172, height: 172)
                .animation(.easeOut(duration: 1.0), value: animateRings)
                .shadow(color: .black.opacity(0.14), radius: 6, x: 0, y: 3)

            VStack(spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    AnimatedInt(
                        value: Int(recovery.readinessScore * 100),
                        font: .system(size: 58, weight: .black, design: .rounded),
                        color: .white
                    )
                    Text("%")
                        .font(.system(size: 23, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.bottom, 4)
                }
                Text(readinessShortLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(readinessTintColor)
            }
        }
    }

    /// The three signals that feed the readiness score. Each falls back
    /// to "—" when its metric is unavailable so the layout stays stable.
    /// Each column deep-links into its health detail — HRV and Resting HR
    /// share the heart-rate detail (it charts both), Sleep opens the sleep
    /// detail — so the number that drives readiness is one tap from its
    /// trend. Matches the week strip's `pressableCard` feedback.
    private var signalStrip: some View {
        HStack(spacing: 0) {
            signalCol(value: hrv.map { "\(Int($0)) ms" } ?? "—", label: "HRV") {
                HeartRateDetailView()
            }
            signalDivider
            signalCol(value: sleepMinutes > 0 ? formattedSleep(sleepMinutes) : "—", label: "Sleep") {
                SleepDetailView()
            }
            signalDivider
            signalCol(value: restingHR.map { "\(Int($0))" } ?? "—", label: "Resting HR") {
                HeartRateDetailView()
            }
        }
    }

    private func signalCol<Destination: View>(value: String, label: String, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            VStack(spacing: 3) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 2) {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.62))
                        .tracking(0.4)
                        .textCase(.uppercase)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.pressableCard)
    }

    private var signalDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.22))
            .frame(width: 1, height: 30)
    }

    private func formattedSleep(_ minutes: Double) -> String {
        let total = Int(minutes)
        return String(format: "%dh %02d", total / 60, total % 60)
    }

    private var streakFallback: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Day Streak")
                .font(.system(.caption, design: .rounded).weight(.bold))
                .foregroundStyle(.white.opacity(0.78))
                .tracking(0.5)
                .textCase(.uppercase)
            HStack(alignment: .lastTextBaseline, spacing: 12) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.white.opacity(0.92))
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 3)
                AnimatedInt(
                    value: currentStreak,
                    font: .system(size: 76, weight: .black, design: .rounded),
                    color: .white
                )
                .shadow(color: .black.opacity(0.22), radius: 10, x: 0, y: 5)
            }
        }
    }

    // MARK: - Readiness helpers

    private var readinessShortLabel: String {
        let s = recovery.readinessScore
        if s >= 0.80 { return "Fully recovered" }
        if s >= 0.60 { return "Mostly recovered" }
        if s >= 0.40 { return "Partially recovered" }
        return "Low readiness"
    }

    private var readinessTintColor: Color {
        let s = recovery.readinessScore
        if s >= 0.60 { return Color(red: 0.25, green: 0.95, blue: 0.55) }
        if s >= 0.40 { return .yellow }
        return .orange
    }

    // MARK: - Week activity strip

    private var currentWeekDays: [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekday = calendar.component(.weekday, from: today) // 1=Sun, 2=Mon…
        let daysFromMonday = (weekday + 5) % 7
        guard let monday = calendar.date(byAdding: .day, value: -daysFromMonday, to: today) else { return [] }
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monday) }
    }

    private var weekActivityStrip: some View {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let days = currentWeekDays
        let labels = ["M", "T", "W", "T", "F", "S", "S"]
        let accentBase = gradientColors.first ?? .accentColor

        return HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.offset) { i, day in
                let isToday = calendar.isDate(day, inSameDayAs: today)
                let isFuture = day > today
                let hasWorkout = allWorkouts.contains { calendar.isDate($0.date, inSameDayAs: day) }

                let workout = allWorkouts.first { calendar.isDate($0.date, inSameDayAs: day) }
                Button {
                    if let workout { onWeekDayTapped(workout) }
                } label: {
                    VStack(spacing: 5) {
                        Text(labels[i])
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(isToday ? 1.0 : 0.55))

                        ZStack {
                            Circle()
                                .fill(hasWorkout ? .white : .white.opacity(isFuture ? 0.08 : 0.15))
                                .frame(width: 28, height: 28)

                            if isToday && !hasWorkout {
                                Circle()
                                    .stroke(.white.opacity(0.7), lineWidth: 1.5)
                                    .frame(width: 28, height: 28)
                            }

                            if hasWorkout {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(accentBase)
                            } else if isToday {
                                Circle()
                                    .fill(.white.opacity(0.6))
                                    .frame(width: 6, height: 6)
                            }
                        }
                    }
                }
                .buttonStyle(.pressableCard)
                .disabled(workout == nil)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }
}

#if DEBUG
#Preview("Hero — Ring (Direction B)") {
    HomeHeroSection(
        greeting: "Good morning, Finbar",
        healthKitEnabled: true,
        healthDataLoaded: true,
        recovery: RecoveryResult(readinessScore: 0.72, muscleResults: [], suggestedWorkoutType: "Push"),
        hrv: 58,
        sleepMinutes: 440,
        restingHR: 52,
        currentStreak: 3,
        allWorkouts: [],
        animateRings: true,
        gradientColors: AppTheme.Gradients.recovery,
        onWeekDayTapped: { _ in }
    )
    .padding()
    .background(Color.black)
}
#endif
