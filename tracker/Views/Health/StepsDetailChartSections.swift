import SwiftUI
import Charts

enum StepsDetailChartSections {

    static func trendCard(
        chartSteps: [(date: Date, steps: Double)],
        stepGoal: Double = StepsDetailHeroSections.stepGoal
    ) -> some View {
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

    static func hourlyCard(hourlySteps: [(hour: Int, steps: Double)]) -> some View {
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

    static func weeklyComparisonCard(metrics: StepsDetailHeroSections.Metrics) -> some View {
        let delta = metrics.thisWeekAvg - metrics.lastWeekAvg
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Week vs Last Week", icon: "arrow.left.arrow.right", color: .green)

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("This Week")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text(HealthFormatters.formatSteps(metrics.thisWeekAvg))
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
                    Text(HealthFormatters.formatSteps(metrics.lastWeekAvg))
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

    @ViewBuilder
    static func distanceTrendCard(
        dailyDistance: [(date: Date, km: Double)],
        dayCount: Int,
        distanceUnit: DistanceUnit
    ) -> some View {
        let chartDistance = Array(dailyDistance.suffix(dayCount))
        if !chartDistance.isEmpty && chartDistance.contains(where: { $0.km > 0.01 }) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Distance", icon: "figure.walk", color: .teal)

                Chart(chartDistance, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Distance", distanceUnit.display(point.km))
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
                        y: .value("Distance", distanceUnit.display(point.km))
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
                        y: .value("Distance", distanceUnit.display(point.km))
                    )
                    .symbolSize(20)
                    .foregroundStyle(.teal)
                }
                .chartYAxisLabel(distanceUnit.label)
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
                    Text(HealthFormatters.formatDistance(avgDist, unit: distanceUnit))
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.teal)
                }
            }
            .appCard()
        }
    }

    static func streakCard(streak: Int, stepGoal: Double = StepsDetailHeroSections.stepGoal) -> some View {
        ZStack(alignment: .topLeading) {
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

    static func statsCard(
        todaySteps: Double,
        metrics: StepsDetailHeroSections.Metrics,
        dailySteps: [(date: Date, steps: Double)],
        dailyDistance: [(date: Date, km: Double)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "list.number", color: .secondary)

            VStack(spacing: 0) {
                statsRow("Today", value: HealthFormatters.formatSteps(todaySteps))
                Divider().padding(.leading, 16)
                statsRow("Daily Average", value: HealthFormatters.formatSteps(metrics.average))
                Divider().padding(.leading, 16)
                statsRow("Best Day", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).max() ?? 0))
                Divider().padding(.leading, 16)
                statsRow(
                    "Least Active",
                    value: HealthFormatters.formatSteps(
                        dailySteps.filter { $0.steps > 0 }.map(\.steps).min() ?? 0
                    )
                )
                Divider().padding(.leading, 16)
                statsRow("Total Steps", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).reduce(0, +)))
                Divider().padding(.leading, 16)
                statsRow(
                    "Total Distance",
                    value: HealthFormatters.formatDistance(dailyDistance.map(\.km).reduce(0, +))
                )
                Divider().padding(.leading, 16)
                statsRow("Days Tracked", value: "\(dailySteps.filter { $0.steps > 0 }.count)")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private static func hourLabel(_ hour: Int) -> String {
        let h = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(h) \(ampm)"
    }

    private static func statsRow(_ title: String, value: String) -> some View {
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
}
