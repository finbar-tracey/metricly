import SwiftUI

/// The top hero card on the home dashboard. Renders either the recovery
/// readiness score with HRV ring + suggestion chip, or a streak fallback
/// when HealthKit is off / data hasn't loaded yet. Includes the week
/// activity strip at the bottom.
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
    let currentStreak: Int
    let allWorkouts: [Workout]
    let animateRings: Bool
    let gradientColors: [Color]
    let onStartWorkout: () -> Void
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
                    readinessRow
                    suggestionChip
                } else {
                    streakFallback
                }

                weekActivityStrip
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Readiness row

    private var readinessRow: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery Readiness")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(.white.opacity(0.78))
                    .tracking(0.5)
                    .textCase(.uppercase)
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    AnimatedInt(
                        value: Int(recovery.readinessScore * 100),
                        font: .system(size: 68, weight: .black, design: .rounded),
                        color: .white
                    )
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 4)
                    Text("%")
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.bottom, 6)
                }
                Text(readinessShortLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(readinessTintColor)
                Text(RecoveryEngine.readinessLabel(recovery.readinessScore))
                    .font(.caption).foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }
            Spacer(minLength: 8)
            if let hrvValue = hrv {
                hrvRing(value: hrvValue)
            }
        }
    }

    @ViewBuilder
    private var suggestionChip: some View {
        let score = recovery.readinessScore
        if score >= 0.50 {
            Button(action: onStartWorkout) {
                chipContent(
                    icon: "bolt.fill",
                    label: "Great day to train \(recovery.suggestedWorkoutType)"
                )
            }
            .buttonStyle(.pressableCard)
        } else if score < 0.40 {
            NavigationLink { MuscleRecoveryView() } label: {
                chipContent(icon: "moon.fill", label: "Rest day recommended")
            }
            .buttonStyle(.pressableCard)
        }
    }

    private func chipContent(icon: String, label: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(label)
                .font(.caption.weight(.semibold))
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.chipRadius))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.chipRadius)
                .stroke(.white.opacity(0.22), lineWidth: 0.5)
        )
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

    private func hrvRing(value: Double) -> some View {
        let progress = CGFloat(min(value / 100.0, 1.0))
        return ZStack {
            // Background track
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 8)
                .frame(width: 96, height: 96)
            // Filled arc
            Circle()
                .trim(from: 0, to: animateRings ? progress : 0)
                .stroke(readinessTintColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 96, height: 96)
                .animation(.easeOut(duration: 1.0), value: animateRings)
            // Inner content
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(readinessTintColor.opacity(0.20))
                        .frame(width: 32, height: 32)
                    Image(systemName: "heart.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(readinessTintColor)
                }
                Text("HRV")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.60))
                Text("\(Int(value)) ms")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
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
