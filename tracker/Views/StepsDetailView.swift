import SwiftUI
import Charts

struct StepsDetailView: View {
    @Environment(\.weightUnit) private var weightUnit
    @State private var dailySteps: [(date: Date, steps: Double)] = []
    @State private var dailyDistance: [(date: Date, km: Double)] = []
    @State private var dailyEnergy: [(date: Date, kcal: Double)] = []
    @State private var hourlySteps: [(hour: Int, steps: Double)] = []
    @State private var todaySteps: Double = 0
    @State private var todayDistance: Double = 0
    @State private var todayEnergy: Double = 0
    @State private var timeRange: TimeRange = .week
    @State private var isLoading = true

    private let stepGoal: Double = 10_000

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case quarter = "90D"
    }

    private var dayCount: Int {
        switch timeRange {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading && todaySteps == 0 {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    heroCard
                    HStack {
                        CapsuleSegmentPicker(options: TimeRange.allCases, selection: $timeRange,
                                             activeColor: .green)
                        Spacer()
                    }
                    trendCard
                    if !hourlySteps.isEmpty && hourlySteps.contains(where: { $0.steps > 0 }) {
                        hourlyCard
                    }
                    if lastWeekAvg > 0 {
                        weeklyComparisonCard
                    }
                    distanceTrendCard
                    if currentGoalStreak > 0 {
                        streakCard
                    }
                    statsCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HeroCard(palette: AppTheme.Gradients.recovery) {
            VStack(alignment: .leading, spacing: 20) {
                // Top: ring + step count
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

                // Status badge
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

                // Stat columns
                HStack(spacing: 0) {
                    HeroStatCol(value: HealthFormatters.formatDistance(todayDistance, unit: weightUnit.distanceUnit),
                                label: "Distance", icon: "figure.walk")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    HeroStatCol(value: HealthFormatters.formatCalories(todayEnergy),
                                label: "Active Cal", icon: "flame.fill")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    let pct = Int(min(100, max(0, todaySteps / stepGoal * 100)))
                    HeroStatCol(value: "\(pct)%", label: "Goal %", icon: "target")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HealthFormatters.formatSteps(todaySteps)) steps of \(HealthFormatters.formatSteps(stepGoal)) goal")
    }

    // MARK: - Trend Card

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Step Trend", icon: "chart.bar.fill", color: .green)

            if !chartSteps.isEmpty {
                Chart {
                    ForEach(chartSteps, id: \.date) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Steps", point.steps)
                        )
                        .foregroundStyle(
                            LinearGradient(
                                colors: point.steps >= stepGoal
                                    ? [Color.green, AppTheme.Signal.recoveryShade]
                                    : [Color.green.opacity(0.55), Color.green.opacity(0.30)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                    }
                    RuleMark(y: .value("Goal", stepGoal))
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .annotation(position: .top, alignment: .trailing) {
                            Text(HealthFormatters.formatSteps(stepGoal))
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxisLabel("steps")
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 5)) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(AppTheme.chartGrid)
                        AxisValueLabel().font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .frame(height: 220)

                let daysMetGoal = chartSteps.filter { $0.steps >= stepGoal }.count
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Goal met \(daysMetGoal) of \(chartSteps.count) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                Text("No step data available.")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
        .appCard()
    }

    // MARK: - Hourly Card

    private var hourlyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today by Hour", icon: "clock.fill", color: .green)

            Chart(hourlySteps, id: \.hour) { point in
                BarMark(
                    x: .value("Hour", point.hour),
                    y: .value("Steps", point.steps)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.green, AppTheme.Signal.recoveryShade],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(3)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: 4)) { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let h = value.as(Int.self) {
                            Text(hourLabel(h))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: 150)

            if let peak = hourlySteps.max(by: { $0.steps < $1.steps }), peak.steps > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Peak: \(HealthFormatters.formatSteps(peak.steps)) steps at \(hourLabel(peak.hour))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .appCard()
    }

    // MARK: - Weekly Comparison Card

    private var weeklyComparisonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Week vs Last Week", icon: "arrow.left.arrow.right", color: .green)

            let delta = thisWeekAvg - lastWeekAvg
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("This Week")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(HealthFormatters.formatSteps(thisWeekAvg))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("avg / day")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Image(systemName: delta >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                    Text(HealthFormatters.formatSteps(abs(delta)))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(delta >= 0 ? .green : .orange)
                }

                VStack(spacing: 4) {
                    Text("Last Week")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(HealthFormatters.formatSteps(lastWeekAvg))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("avg / day")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        .appCard()
    }

    // MARK: - Distance Card

    @ViewBuilder
    private var distanceTrendCard: some View {
        let chartDistance = Array(dailyDistance.suffix(dayCount))
        let distUnit = weightUnit.distanceUnit
        if !chartDistance.isEmpty && chartDistance.contains(where: { $0.km > 0.01 }) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Distance", icon: "figure.walk", color: .teal)

                Chart(chartDistance, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", distUnit.display(point.km))
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.teal.opacity(0.55),
                                Color.teal.opacity(0.22),
                                Color.teal.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", distUnit.display(point.km))
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.teal, Color(red: 0.10, green: 0.65, blue: 0.62)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.teal.opacity(0.30), radius: 5, y: 2)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", distUnit.display(point.km))
                    )
                    .symbolSize(20)
                    .foregroundStyle(.teal)
                }
                .chartYAxisLabel(distUnit.label)
                .frame(height: 160)

                let avgDist = chartDistance.map(\.km).reduce(0, +) / Double(max(1, chartDistance.count))
                HStack {
                    Image(systemName: "ruler")
                        .font(.caption2)
                        .foregroundStyle(.teal)
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(HealthFormatters.formatDistance(avgDist, unit: distUnit))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.teal)
                }
            }
            .appCard()
        }
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let streak = currentGoalStreak
        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.orange, Color.red.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 160)
                .offset(x: 200, y: -50)

            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Goal Streak")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(streak)")
                            .font(.system(size: 52, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text(streak == 1 ? "day" : "days")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.80))
                    }
                    Text("consecutive days at \(HealthFormatters.formatSteps(stepGoal))+ steps")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.system(size: 52, weight: .bold))
                    .foregroundStyle(.white.opacity(0.30))
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "list.number", color: .secondary)

            VStack(spacing: 0) {
                statsRow("Today", value: HealthFormatters.formatSteps(todaySteps))
                Divider().padding(.leading, 16)
                statsRow("Daily Average", value: HealthFormatters.formatSteps(average))
                Divider().padding(.leading, 16)
                statsRow("Best Day", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).max() ?? 0))
                Divider().padding(.leading, 16)
                statsRow("Least Active", value: HealthFormatters.formatSteps(
                    dailySteps.filter { $0.steps > 0 }.map(\.steps).min() ?? 0
                ))
                Divider().padding(.leading, 16)
                statsRow("Total Steps", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).reduce(0, +)))
                Divider().padding(.leading, 16)
                statsRow("Total Distance", value: HealthFormatters.formatDistance(
                    dailyDistance.map(\.km).reduce(0, +)
                ))
                Divider().padding(.leading, 16)
                statsRow("Days Tracked", value: "\(dailySteps.filter { $0.steps > 0 }.count)")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Computed Properties

    private var stepProgressColor: Color {
        let pct = todaySteps / stepGoal
        if pct >= 1.0 { return .green }
        if pct >= 0.7 { return .green }
        if pct >= 0.4 { return .yellow }
        return .orange
    }

    private var average: Double {
        let active = dailySteps.filter { $0.steps > 0 }
        guard !active.isEmpty else { return 0 }
        return active.map(\.steps).reduce(0, +) / Double(active.count)
    }

    private var chartSteps: [(date: Date, steps: Double)] {
        Array(dailySteps.suffix(dayCount))
    }

    private var thisWeekAvg: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = dailySteps.filter { $0.date >= weekStart && $0.steps > 0 }
        guard !thisWeek.isEmpty else { return 0 }
        return thisWeek.map(\.steps).reduce(0, +) / Double(thisWeek.count)
    }

    private var lastWeekAvg: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
        let lastWeek = dailySteps.filter { $0.date >= prevStart && $0.date < weekStart && $0.steps > 0 }
        guard !lastWeek.isEmpty else { return 0 }
        return lastWeek.map(\.steps).reduce(0, +) / Double(lastWeek.count)
    }

    private var currentGoalStreak: Int {
        let sorted = dailySteps.sorted { $0.date > $1.date }
        var streak = 0
        for entry in sorted {
            if entry.steps >= stepGoal {
                streak += 1
            } else if entry.steps > 0 {
                break
            }
        }
        return streak
    }

    // MARK: - Helpers

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private func statsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthDataCache.shared
        let fetchDays = max(dayCount, 14)
        async let stepsData = hk.fetchDailySteps(days: fetchDays)
        async let distData = hk.fetchDailyDistance(days: fetchDays)
        async let energyData = hk.fetchDailyActiveEnergy(days: fetchDays)
        async let hourlyData = hk.fetchHourlySteps(for: .now)
        async let todayStepsData = hk.fetchSteps(for: .now)
        async let todayDistData = hk.fetchDistance(for: .now)
        async let todayEnergyData = hk.fetchActiveEnergy(for: .now)
        dailySteps = (try? await stepsData) ?? []
        dailyDistance = (try? await distData) ?? []
        dailyEnergy = (try? await energyData) ?? []
        hourlySteps = (try? await hourlyData) ?? []
        todaySteps = (try? await todayStepsData) ?? 0
        todayDistance = (try? await todayDistData) ?? 0
        todayEnergy = (try? await todayEnergyData) ?? 0
    }
}
