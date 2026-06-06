import SwiftUI

enum StepsDetailHeroSections {

    static let stepGoal: Double = 10_000

    struct Metrics {
        let average: Double
        let thisWeekAvg: Double
        let lastWeekAvg: Double
        let currentGoalStreak: Int

        static func make(
            dailySteps: [(date: Date, steps: Double)],
            stepGoal: Double = stepGoal
        ) -> Metrics {
            let active = dailySteps.filter { $0.steps > 0 }
            let average: Double = active.isEmpty ? 0
                : active.map(\.steps).reduce(0, +) / Double(active.count)

            let calendar = Calendar.current
            let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
            let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
            let thisWeek = dailySteps.filter { $0.date >= weekStart && $0.steps > 0 }
            let lastWeek = dailySteps.filter { $0.date >= prevStart && $0.date < weekStart && $0.steps > 0 }
            let thisWeekAvg = thisWeek.isEmpty ? 0 : thisWeek.map(\.steps).reduce(0, +) / Double(thisWeek.count)
            let lastWeekAvg = lastWeek.isEmpty ? 0 : lastWeek.map(\.steps).reduce(0, +) / Double(lastWeek.count)

            let sorted = dailySteps.sorted { $0.date > $1.date }
            var streak = 0
            for entry in sorted {
                if entry.steps >= stepGoal {
                    streak += 1
                } else if entry.steps > 0 {
                    break
                }
            }

            return Metrics(
                average: average,
                thisWeekAvg: thisWeekAvg,
                lastWeekAvg: lastWeekAvg,
                currentGoalStreak: streak
            )
        }
    }

    static func heroCard(
        todaySteps: Double,
        todayDistance: Double,
        todayEnergy: Double,
        distanceUnit: DistanceUnit,
        stepGoal: Double = stepGoal
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.recovery) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: min(1.0, todaySteps / stepGoal))
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: todaySteps)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                    }
                    .frame(width: 70, height: 70)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(HealthFormatters.formatSteps(todaySteps))
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                        Text("of \(HealthFormatters.formatSteps(stepGoal)) goal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }

                if todaySteps >= stepGoal {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption.bold())
                        Text("Goal Reached!")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                } else {
                    let remaining = stepGoal - todaySteps
                    Text("\(HealthFormatters.formatSteps(remaining)) to go")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
                }

                HStack(spacing: 0) {
                    HeroStatCol(
                        value: HealthFormatters.formatDistance(todayDistance, unit: distanceUnit),
                        label: "Distance",
                        icon: "figure.walk"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(
                        value: HealthFormatters.formatCalories(todayEnergy),
                        label: "Active Cal",
                        icon: "flame.fill"
                    )
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    let pct = Int(min(100, max(0, todaySteps / stepGoal * 100)))
                    HeroStatCol(value: "\(pct)%", label: "Goal %", icon: "target")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HealthFormatters.formatSteps(todaySteps)) steps of \(HealthFormatters.formatSteps(stepGoal)) goal")
    }
}
