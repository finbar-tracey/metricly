import SwiftUI

/// Two side-by-side mini cards on the home dashboard: today's plan
/// and key metrics. Bundled in one file because they're visually a
/// pair and always render together.
struct HomePlanAndMetricsRow: View {
    let plan: TodayPlan
    let scheduledNameForToday: String?
    let todaysWorkouts: [Workout]
    let todayTotalSets: Int
    let todayTotalVolumeKg: Double
    let weightUnit: WeightUnit
    let healthDataLoaded: Bool
    let sleepMinutes: Double
    let restingHR: Double?
    let activeCalories: Double
    let todayWaterMl: Double
    let waterProgress: Double
    let activitiesThisWeek: Int
    let weeklyGoal: Int
    let currentStreak: Int
    let onStartWorkout: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            todayPlanMiniCard
            keyMetricsMiniCard
        }
    }

    // MARK: - Today's plan mini

    private var todayPlanMiniCard: some View {
        // Prefer the adaptive recommendation here so the mini card stays
        // in sync with the full Adaptive Plan section and the Start
        // flow. The engine may swap a stale schedule (e.g. Legs on a
        // day the user already smashed legs twice) for something
        // smarter, and the mini card should reflect that.
        let adaptive: String? = {
            guard plan.intensity != .rest,
                  !plan.recommendedName.isEmpty,
                  plan.recommendedName != "—" else { return nil }
            return plan.recommendedName
        }()
        let planned = adaptive ?? scheduledNameForToday
        let doneCount = todaysWorkouts.filter(\.isFinished).count
        let totalCount = max(1, todaysWorkouts.count)
        let progress = Double(doneCount) / Double(totalCount)
        let hasPlan = planned?.isEmpty == false

        return VStack(alignment: .leading, spacing: 10) {
            Text("Today's Plan")
                .font(.system(.headline, design: .rounded).weight(.bold))

            if hasPlan, let name = planned {
                HStack(spacing: 4) {
                    Text("\(doneCount)/\(totalCount) completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(doneCount >= totalCount ? Color.green : Color.accentColor)
                    Spacer()
                }
                GradientProgressBar(value: progress, color: doneCount >= totalCount ? .green : .accentColor, height: 5)
                    .padding(.bottom, 2)

                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(doneCount > 0 ? Color.green.opacity(0.15) : Color(.tertiarySystemGroupedBackground))
                            .frame(width: 30, height: 30)
                        Image(systemName: doneCount > 0 ? "checkmark" : "dumbbell.fill")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(doneCount > 0 ? Color.green : Color.accentColor)
                    }
                    Text(name)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text(todaysWorkouts.isEmpty ? "No workout scheduled" : "\(todaysWorkouts.count) workout\(todaysWorkouts.count == 1 ? "" : "s") today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !todaysWorkouts.isEmpty {
                        Text("\(todayTotalSets) sets · \(weightUnit.formatShort(todayTotalVolumeKg))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer()

            Button(action: onStartWorkout) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text("Start Workout")
                        .font(.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .padding(.vertical, 11)
                .background(
                    LinearGradient(
                        colors: [.green, AppTheme.Signal.actionGreen],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 11)
                )
                .shadow(color: .green.opacity(0.40), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.pressableCard)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    // MARK: - Key metrics mini

    private var keyMetricsMiniCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Key Metrics")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Spacer()
                NavigationLink { HealthDashboardView() } label: {
                    Text("View all")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }

            if healthDataLoaded {
                VStack(spacing: 0) {
                    miniMetricRow(icon: "moon.zzz.fill", color: .indigo, label: "Sleep",
                                  value: HealthFormatters.formatSleepShort(sleepMinutes),
                                  status: sleepMinutes >= 420 ? "Good" : "Fair",
                                  good: sleepMinutes >= 420)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "heart.fill", color: .red, label: "Resting HR",
                                  value: restingHR.map { "\(Int($0)) bpm" } ?? "—",
                                  status: restingHR.map { $0 < 70 ? "Good" : "Fair" } ?? "",
                                  good: restingHR.map { $0 < 70 } ?? false)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "flame.fill", color: .orange, label: "Calories",
                                  value: "\(Int(activeCalories))",
                                  status: activeCalories >= 300 ? "On track" : "Low",
                                  good: activeCalories >= 300)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "drop.fill", color: .cyan, label: "Hydration",
                                  value: todayWaterMl >= 1000 ? String(format: "%.1f L", todayWaterMl / 1000) : "\(Int(todayWaterMl)) ml",
                                  status: waterProgress >= 0.7 ? "Good" : "Low",
                                  good: waterProgress >= 0.7)
                }
            } else {
                VStack(spacing: 0) {
                    miniMetricRow(icon: "dumbbell.fill", color: .accentColor, label: "This week",
                                  value: "\(activitiesThisWeek)", status: weeklyGoal > 0 ? "/ \(weeklyGoal) goal" : "workouts",
                                  good: weeklyGoal > 0 ? activitiesThisWeek >= weeklyGoal : true)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "flame.fill", color: .orange, label: "Streak",
                                  value: "\(currentStreak) day\(currentStreak == 1 ? "" : "s")",
                                  status: currentStreak >= 3 ? "Active" : "",
                                  good: currentStreak >= 3)
                    Divider().padding(.vertical, 5)
                    miniMetricRow(icon: "scalemass.fill", color: .purple, label: "Volume today",
                                  value: weightUnit.formatShort(todayTotalVolumeKg),
                                  status: todayTotalSets > 0 ? "\(todayTotalSets) sets" : "",
                                  good: true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 168, alignment: .topLeading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.10), radius: 14, x: 0, y: 5)
    }

    private func miniMetricRow(icon: String, color: Color, label: String, value: String, status: String, good: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 18)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                if !status.isEmpty {
                    Text(status)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(good ? Color.green : Color.orange)
                }
            }
        }
    }
}
