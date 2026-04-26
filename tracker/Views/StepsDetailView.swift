import SwiftUI
import Charts

struct StepsDetailView: View {
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
                    timeRangePicker
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
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.green, Color(red: 0.1, green: 0.72, blue: 0.35).opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 220)
                .offset(x: 160, y: -70)

            VStack(alignment: .leading, spacing: 20) {
                // Top: ring + step count
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(1.0, todaySteps / stepGoal))
                            .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: todaySteps)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(HealthFormatters.formatSteps(todaySteps))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                        Text("of \(HealthFormatters.formatSteps(stepGoal)) goal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.20), in: Capsule())
                } else {
                    let remaining = stepGoal - todaySteps
                    Text("\(HealthFormatters.formatSteps(remaining)) to go")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.15), in: Capsule())
                }

                // Stat columns
                HStack(spacing: 0) {
                    heroStatColumn(icon: "figure.walk", label: "Distance", value: HealthFormatters.formatDistance(todayDistance))
                    Divider().frame(height: 32).overlay(.white.opacity(0.30))
                    heroStatColumn(icon: "flame.fill", label: "Active Cal", value: HealthFormatters.formatCalories(todayEnergy))
                    Divider().frame(height: 32).overlay(.white.opacity(0.30))
                    let pct = Int(min(100, max(0, todaySteps / stepGoal * 100)))
                    heroStatColumn(icon: "target", label: "Goal %", value: "\(pct)%")
                }
            }
            .padding(20)
        }
        .heroCard()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HealthFormatters.formatSteps(todaySteps)) steps of \(HealthFormatters.formatSteps(stepGoal)) goal")
    }

    private func heroStatColumn(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.80))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Time Range Picker

    private var timeRangePicker: some View {
        HStack(spacing: 6) {
            ForEach(TimeRange.allCases, id: \.self) { range in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        timeRange = range
                    }
                } label: {
                    Text(range.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(timeRange == range ? .white : .primary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(
                            timeRange == range
                                ? AnyShapeStyle(Color.green)
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                            in: Capsule()
                        )
                        .shadow(color: timeRange == range ? Color.green.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
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
                        .foregroundStyle(point.steps >= stepGoal ? Color.green.gradient : Color.green.opacity(0.5).gradient)
                        .cornerRadius(4)
                    }
                    RuleMark(y: .value("Goal", stepGoal))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text(HealthFormatters.formatSteps(stepGoal))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxisLabel("steps")
                .frame(height: 200)

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
                .foregroundStyle(.green.gradient)
                .cornerRadius(2)
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
        if !chartDistance.isEmpty && chartDistance.contains(where: { $0.km > 0.01 }) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Distance", icon: "figure.walk", color: .teal)

                Chart(chartDistance, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", point.km)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.teal.opacity(0.15).gradient)

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", point.km)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.teal)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", point.km)
                    )
                    .symbolSize(20)
                    .foregroundStyle(.teal)
                }
                .chartYAxisLabel("km")
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
                    Text(HealthFormatters.formatDistance(avgDist))
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
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
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
        let hk = HealthKitManager.shared
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
