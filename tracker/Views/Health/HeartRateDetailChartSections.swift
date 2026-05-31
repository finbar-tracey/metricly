import SwiftUI
import Charts

enum HeartRateDetailChartSections {

    static func restingTrendCard(
        dailyRestingHR: [(date: Date, bpm: Double)],
        isLoading: Bool,
        metrics: HeartRateDetailSections.Metrics
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Resting Heart Rate", icon: "heart.fill", color: .red)
            if !dailyRestingHR.isEmpty {
                Chart(dailyRestingHR, id: \.date) { point in
                    AreaMark(x: .value("Date", point.date, unit: .day), y: .value("BPM", point.bpm))
                        .interpolationMethod(.catmullRom)
                        .foregroundStyle(LinearGradient(colors: [Color.red.opacity(0.55), Color.red.opacity(0.22), Color.red.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("Date", point.date, unit: .day), y: .value("BPM", point.bpm))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(LinearGradient(colors: [.red, Color(red: 0.85, green: 0.20, blue: 0.30)], startPoint: .leading, endPoint: .trailing))
                    PointMark(x: .value("Date", point.date, unit: .day), y: .value("BPM", point.bpm))
                        .symbolSize(36).foregroundStyle(Color.red)
                }
                .chartYAxisLabel("bpm")
                .chartYScale(domain: metrics.restingChartDomain)
                .frame(height: 220)
                if let trend = metrics.restingTrend {
                    HStack(spacing: 7) {
                        Image(systemName: trend <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(trend <= 0 ? .green : .orange)
                        Text("\(trend <= 0 ? "Improving" : "Increasing") — \(abs(Int(trend))) bpm vs start of period")
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(trend <= 0 ? .green : .orange)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background((trend <= 0 ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                }
            } else if !isLoading {
                Text("No resting heart rate data available.")
                    .foregroundStyle(.secondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }
        }
        .appCard()
    }

    static func hrRangeCard(
        dailyHRRange: [(date: Date, min: Double, max: Double)],
        metrics: HeartRateDetailSections.Metrics
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Daily Range", icon: "arrow.up.arrow.down.circle.fill", color: .orange)
            Chart(dailyHRRange, id: \.date) { point in
                BarMark(x: .value("Date", point.date, unit: .day), yStart: .value("Min", point.min), yEnd: .value("Max", point.max))
                    .foregroundStyle(LinearGradient(colors: [Color.orange.opacity(0.55), Color.red.opacity(0.30)], startPoint: .top, endPoint: .bottom))
                    .cornerRadius(5)
            }
            .chartYScale(domain: metrics.rangeChartDomain)
            .frame(height: 200)
        }
        .appCard()
    }

    static func hrvCard(
        dailyHRV: [(date: Date, ms: Double)],
        metrics: HeartRateDetailSections.Metrics
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Variability", icon: "waveform.path.ecg", color: .purple)
            Chart(dailyHRV, id: \.date) { point in
                AreaMark(x: .value("Date", point.date, unit: .day), y: .value("HRV", point.ms))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(LinearGradient(colors: [Color.purple.opacity(0.55), Color.purple.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                LineMark(x: .value("Date", point.date, unit: .day), y: .value("HRV", point.ms))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .foregroundStyle(.purple)
            }
            .chartYScale(domain: metrics.hrvChartDomain)
            .frame(height: 180)
            if let avgHRV = metrics.averageHRV {
                Text("Average \(Int(avgHRV)) ms — \(hrvInterpretation(avgHRV))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    static func weeklyComparisonCard(metrics: HeartRateDetailSections.Metrics) -> some View {
        let delta = metrics.thisWeekAvgResting - metrics.lastWeekAvgResting
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Week vs Last Week", icon: "arrow.left.arrow.right", color: .red)
            HStack(spacing: 0) {
                weekColumn("THIS WEEK", bpm: metrics.thisWeekAvgResting, color: .red)
                deltaBadge(delta: delta)
                weekColumn("LAST WEEK", bpm: metrics.lastWeekAvgResting, color: .secondary)
            }
        }
        .appCard()
    }

    static func statsCard(
        todayResting: Double?,
        metrics: HeartRateDetailSections.Metrics,
        dayCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "list.number", color: .secondary)
            VStack(spacing: 0) {
                statsRow("Current Resting", value: todayResting.map { "\(Int($0)) bpm" } ?? "—")
                Divider().padding(.leading, 16)
                statsRow("Average Resting", value: metrics.averageResting.map { "\(Int($0)) bpm" } ?? "—")
                Divider().padding(.leading, 16)
                statsRow("Lowest Resting", value: metrics.lowestResting.map { "\(Int($0)) bpm" } ?? "—")
                Divider().padding(.leading, 16)
                statsRow("Highest Resting", value: metrics.highestResting.map { "\(Int($0)) bpm" } ?? "—")
                if let avgHRV = metrics.averageHRV {
                    Divider().padding(.leading, 16)
                    statsRow("Average HRV", value: "\(Int(avgHRV)) ms")
                }
                Divider().padding(.leading, 16)
                statsRow("Data Points", value: "\(dayCount) days")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private static func weekColumn(_ title: String, bpm: Double, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title).font(.system(size: 10, weight: .bold, design: .rounded)).tracking(0.5).foregroundStyle(.secondary)
            Text("\(Int(bpm))").font(.system(size: 26, weight: .black, design: .rounded)).monospacedDigit().foregroundStyle(color)
            Text("bpm avg").font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    private static func deltaBadge(delta: Double) -> some View {
        VStack(spacing: 4) {
            Image(systemName: delta <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text("\(abs(Int(delta))) bpm")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(delta <= 0 ? .green : .orange)
        }
    }

    private static func statsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(value).font(.subheadline.bold().monospacedDigit()).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    private static func hrvInterpretation(_ ms: Double) -> String {
        if ms >= 50 { return "Good recovery capacity" }
        if ms >= 30 { return "Moderate — consider recovery days" }
        return "Low — prioritize rest and recovery"
    }
}
