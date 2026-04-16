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
        List {
            if isLoading && todaySteps == 0 {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else {
                todaySummarySection
                hourlyBreakdownSection
                trendSection
                weeklyComparisonSection
                distanceTrendSection
                streakSection
                statsSection
            }
        }
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Section 1: Today Summary

    private var todaySummarySection: some View {
        Section {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(1.0, todaySteps / stepGoal))
                        .stroke(stepProgressColor.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: todaySteps)
                    VStack(spacing: 2) {
                        Text(HealthFormatters.formatSteps(todaySteps))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("of \(HealthFormatters.formatSteps(stepGoal))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 130, height: 130)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(HealthFormatters.formatSteps(todaySteps)) steps of \(HealthFormatters.formatSteps(stepGoal)) goal")

                if todaySteps >= stepGoal {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Goal Reached!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Color.green.opacity(0.1), in: Capsule())
                } else {
                    let remaining = stepGoal - todaySteps
                    Text("\(HealthFormatters.formatSteps(remaining)) to go")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .foregroundStyle(.green)
                        Text(HealthFormatters.formatDistance(todayDistance))
                            .font(.subheadline.bold().monospacedDigit())
                        Text("Distance")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    VStack(spacing: 2) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text(HealthFormatters.formatCalories(todayEnergy))
                            .font(.subheadline.bold().monospacedDigit())
                        Text("Active Energy")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section 2: Hourly Breakdown

    @ViewBuilder
    private var hourlyBreakdownSection: some View {
        if !hourlySteps.isEmpty && hourlySteps.contains(where: { $0.steps > 0 }) {
            Section("Today by Hour") {
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
                .padding(.vertical, 8)

                if let peak = hourlySteps.max(by: { $0.steps < $1.steps }), peak.steps > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Peak: \(HealthFormatters.formatSteps(peak.steps)) steps at \(hourLabel(peak.hour))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Step Trend

    private var trendSection: some View {
        Section("Step Trend") {
            Picker("Range", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

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
                .padding(.vertical, 8)

                let daysMetGoal = chartSteps.filter { $0.steps >= stepGoal }.count
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                    Text("Goal met \(daysMetGoal) of \(chartSteps.count) days")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if !isLoading {
                Text("No step data available.")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Section 4: Weekly Comparison

    @ViewBuilder
    private var weeklyComparisonSection: some View {
        if lastWeekAvg > 0 {
            Section("This Week vs Last Week") {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSteps(thisWeekAvg))
                            .font(.title3.bold().monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)

                    let delta = thisWeekAvg - lastWeekAvg
                    VStack(spacing: 2) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.title3)
                            .foregroundStyle(delta >= 0 ? .green : .orange)
                        Text(HealthFormatters.formatSteps(abs(delta)))
                            .font(.caption.bold())
                            .foregroundStyle(delta >= 0 ? .green : .orange)
                    }

                    VStack(spacing: 4) {
                        Text("Last Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSteps(lastWeekAvg))
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
            }
        }
    }

    // MARK: - Section 5: Distance Trend

    @ViewBuilder
    private var distanceTrendSection: some View {
        let chartDistance = Array(dailyDistance.suffix(dayCount))
        if !chartDistance.isEmpty && chartDistance.contains(where: { $0.km > 0.01 }) {
            Section("Distance") {
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
                .padding(.vertical, 8)

                let avgDist = chartDistance.map(\.km).reduce(0, +) / Double(max(1, chartDistance.count))
                HStack {
                    Text("Daily Average")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(HealthFormatters.formatDistance(avgDist))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.teal)
                }
            }
        }
    }

    // MARK: - Section 6: Goal Streak

    @ViewBuilder
    private var streakSection: some View {
        let streak = currentGoalStreak
        if streak > 0 {
            Section("Goal Streak") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(streak)")
                                .font(.title.bold().monospacedDigit())
                                .foregroundStyle(.green)
                            Text(streak == 1 ? "day" : "days")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Text("consecutive days at \(HealthFormatters.formatSteps(stepGoal))+ steps")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "flame.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.orange.gradient)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Section 7: Stats

    private var statsSection: some View {
        Section("Stats") {
            statsRow("Today", value: HealthFormatters.formatSteps(todaySteps))
            statsRow("Daily Average", value: HealthFormatters.formatSteps(average))
            statsRow("Best Day", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).max() ?? 0))
            statsRow("Least Active", value: HealthFormatters.formatSteps(
                dailySteps.filter { $0.steps > 0 }.map(\.steps).min() ?? 0
            ))
            statsRow("Total Steps", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).reduce(0, +)))
            statsRow("Total Distance", value: HealthFormatters.formatDistance(
                dailyDistance.map(\.km).reduce(0, +)
            ))
            statsRow("Days Tracked", value: "\(dailySteps.filter { $0.steps > 0 }.count)")
        }
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

    // MARK: - Shared Helpers

    private func statsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }
}
