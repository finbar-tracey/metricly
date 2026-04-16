import SwiftUI
import Charts

struct HeartRateDetailView: View {
    @State private var dailyRestingHR: [(date: Date, bpm: Double)] = []
    @State private var dailyHRRange: [(date: Date, min: Double, max: Double)] = []
    @State private var dailyHRV: [(date: Date, ms: Double)] = []
    @State private var todayStats: (min: Double, max: Double, avg: Double)?
    @State private var todayResting: Double?
    @State private var todayHRV: Double?
    @State private var timeRange: TimeRange = .month
    @State private var isLoading = true

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
            if isLoading && todayStats == nil {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else {
                todaySummarySection
                heartRateZonesSection
                restingTrendSection
                hrRangeSection
                hrvSection
                weeklyComparisonSection
                statsSection
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Section 1: Today Summary

    private var todaySummarySection: some View {
        Section {
            VStack(spacing: 16) {
                if let stats = todayStats {
                    HStack(spacing: 0) {
                        statColumn(label: "Min", value: "\(Int(stats.min))", unit: "bpm", color: .blue)
                        Divider().frame(height: 50)
                        statColumn(label: "Avg", value: "\(Int(stats.avg))", unit: "bpm", color: .red)
                        Divider().frame(height: 50)
                        statColumn(label: "Max", value: "\(Int(stats.max))", unit: "bpm", color: .orange)
                    }
                } else {
                    Text("No heart rate data today")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 24) {
                    if let resting = todayResting {
                        VStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(.pink)
                            Text("\(Int(resting))")
                                .font(.subheadline.bold().monospacedDigit())
                            Text("Resting")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let hrv = todayHRV {
                        VStack(spacing: 2) {
                            Image(systemName: "waveform.path.ecg")
                                .foregroundStyle(.purple)
                            Text("\(Int(hrv)) ms")
                                .font(.subheadline.bold().monospacedDigit())
                            Text("HRV")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let stats = todayStats {
                        VStack(spacing: 2) {
                            Image(systemName: "arrow.up.arrow.down")
                                .foregroundStyle(.teal)
                            Text("\(Int(stats.max - stats.min))")
                                .font(.subheadline.bold().monospacedDigit())
                            Text("Range")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        } header: {
            Text("Today")
        }
    }

    // MARK: - Section 2: Heart Rate Zones

    @ViewBuilder
    private var heartRateZonesSection: some View {
        if let stats = todayStats {
            Section("Heart Rate Zones") {
                let zones = heartRateZones(min: stats.min, max: stats.max, avg: stats.avg)
                ForEach(zones, id: \.name) { zone in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zone.color)
                            .frame(width: 4, height: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(zone.name)
                                .font(.subheadline.weight(.semibold))
                            Text(zone.range)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if zone.isActive {
                            Text("Active")
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(zone.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(zone.color)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Section 3: Resting HR Trend

    private var restingTrendSection: some View {
        Section("Resting Heart Rate") {
            Picker("Range", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            if !dailyRestingHR.isEmpty {
                Chart(dailyRestingHR, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.red.opacity(0.15).gradient)

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.red)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .symbolSize(20)
                    .foregroundStyle(.red)
                }
                .chartYAxisLabel("bpm")
                .chartYScale(domain: restingChartDomain)
                .frame(height: 200)
                .padding(.vertical, 8)

                if let trend = restingTrend {
                    HStack(spacing: 4) {
                        Image(systemName: trend >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                            .foregroundStyle(trend <= 0 ? .green : .orange)
                        Text("\(trend <= 0 ? "Improving" : "Increasing") — \(abs(Int(trend))) bpm vs start of period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else if !isLoading {
                Text("No resting heart rate data available.")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Section 4: Daily HR Range

    @ViewBuilder
    private var hrRangeSection: some View {
        if !dailyHRRange.isEmpty {
            Section("Daily Range") {
                Chart(dailyHRRange, id: \.date) { point in
                    BarMark(
                        x: .value("Date", point.date, unit: .day),
                        yStart: .value("Min", point.min),
                        yEnd: .value("Max", point.max)
                    )
                    .foregroundStyle(.red.opacity(0.3).gradient)
                    .cornerRadius(3)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Min", point.min)
                    )
                    .symbolSize(16)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Max", point.max)
                    )
                    .symbolSize(16)
                    .foregroundStyle(.orange)
                }
                .chartYAxisLabel("bpm")
                .chartYScale(domain: rangeChartDomain)
                .frame(height: 180)
                .padding(.vertical, 8)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(.blue).frame(width: 8, height: 8)
                        Text("Min").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 8, height: 8)
                        Text("Max").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Section 5: HRV Trend

    @ViewBuilder
    private var hrvSection: some View {
        if !dailyHRV.isEmpty {
            Section("Heart Rate Variability") {
                Chart(dailyHRV, id: \.date) { point in
                    AreaMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.ms)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.purple.opacity(0.15).gradient)

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.ms)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.purple)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("HRV", point.ms)
                    )
                    .symbolSize(20)
                    .foregroundStyle(.purple)
                }
                .chartYAxisLabel("ms")
                .chartYScale(domain: hrvChartDomain)
                .frame(height: 160)
                .padding(.vertical, 8)

                let avgHRV = dailyHRV.map(\.ms).reduce(0, +) / Double(dailyHRV.count)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Average: \(Int(avgHRV)) ms")
                            .font(.caption.bold())
                        Text(hrvInterpretation(avgHRV))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "waveform.path.ecg")
                        .font(.title2)
                        .foregroundStyle(.purple.opacity(0.5))
                }
            }
        }
    }

    // MARK: - Section 6: Weekly Comparison

    @ViewBuilder
    private var weeklyComparisonSection: some View {
        if lastWeekAvgResting > 0 {
            Section("This Week vs Last Week") {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(thisWeekAvgResting)) bpm")
                            .font(.title3.bold().monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)

                    let delta = thisWeekAvgResting - lastWeekAvgResting
                    VStack(spacing: 2) {
                        // Lower resting HR is better
                        Image(systemName: delta <= 0 ? "arrow.down.right" : "arrow.up.right")
                            .font(.title3)
                            .foregroundStyle(delta <= 0 ? .green : .orange)
                        Text("\(abs(Int(delta))) bpm")
                            .font(.caption.bold())
                            .foregroundStyle(delta <= 0 ? .green : .orange)
                    }

                    VStack(spacing: 4) {
                        Text("Last Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(Int(lastWeekAvgResting)) bpm")
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

    // MARK: - Section 7: Stats

    private var statsSection: some View {
        Section("Stats") {
            statsRow("Current Resting", value: todayResting.map { "\(Int($0)) bpm" } ?? "—")
            statsRow("Average Resting", value: averageResting.map { "\(Int($0)) bpm" } ?? "—")
            statsRow("Lowest Resting", value: lowestResting.map { "\(Int($0)) bpm" } ?? "—")
            statsRow("Highest Resting", value: highestResting.map { "\(Int($0)) bpm" } ?? "—")
            if let avgHRV = averageHRV {
                statsRow("Average HRV", value: "\(Int(avgHRV)) ms")
            }
            statsRow("Data Points", value: "\(dailyRestingHR.count) days")
        }
    }

    // MARK: - Heart Rate Zones

    private struct HRZone {
        let name: String
        let range: String
        let color: Color
        let isActive: Bool
    }

    private func heartRateZones(min: Double, max: Double, avg: Double) -> [HRZone] {
        // Estimated max HR (220 - age). Using avg resting as proxy: lower resting → fitter → higher max.
        // Default to 190 as a reasonable estimate without age data.
        let estimatedMax = 190.0
        let restZone = estimatedMax * 0.5
        let fatBurnLow = estimatedMax * 0.5
        let fatBurnHigh = estimatedMax * 0.7
        let cardioLow = estimatedMax * 0.7
        let cardioHigh = estimatedMax * 0.85
        let peakLow = estimatedMax * 0.85

        return [
            HRZone(
                name: "Rest",
                range: "< \(Int(restZone)) bpm",
                color: .blue,
                isActive: min < restZone
            ),
            HRZone(
                name: "Fat Burn",
                range: "\(Int(fatBurnLow))–\(Int(fatBurnHigh)) bpm",
                color: .green,
                isActive: max >= fatBurnLow && min <= fatBurnHigh
            ),
            HRZone(
                name: "Cardio",
                range: "\(Int(cardioLow))–\(Int(cardioHigh)) bpm",
                color: .yellow,
                isActive: max >= cardioLow && min <= cardioHigh
            ),
            HRZone(
                name: "Peak",
                range: "> \(Int(peakLow)) bpm",
                color: .red,
                isActive: max >= peakLow
            )
        ]
    }

    // MARK: - Computed Properties

    private var averageResting: Double? {
        guard !dailyRestingHR.isEmpty else { return nil }
        return dailyRestingHR.map(\.bpm).reduce(0, +) / Double(dailyRestingHR.count)
    }

    private var lowestResting: Double? {
        dailyRestingHR.map(\.bpm).min()
    }

    private var highestResting: Double? {
        dailyRestingHR.map(\.bpm).max()
    }

    private var averageHRV: Double? {
        guard !dailyHRV.isEmpty else { return nil }
        return dailyHRV.map(\.ms).reduce(0, +) / Double(dailyHRV.count)
    }

    private var restingTrend: Double? {
        guard dailyRestingHR.count >= 3,
              let first = dailyRestingHR.first?.bpm,
              let last = dailyRestingHR.last?.bpm else { return nil }
        return last - first
    }

    private var thisWeekAvgResting: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = dailyRestingHR.filter { $0.date >= weekStart }
        guard !thisWeek.isEmpty else { return 0 }
        return thisWeek.map(\.bpm).reduce(0, +) / Double(thisWeek.count)
    }

    private var lastWeekAvgResting: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
        let lastWeek = dailyRestingHR.filter { $0.date >= prevStart && $0.date < weekStart }
        guard !lastWeek.isEmpty else { return 0 }
        return lastWeek.map(\.bpm).reduce(0, +) / Double(lastWeek.count)
    }

    // MARK: - Chart Domains

    private var restingChartDomain: ClosedRange<Double> {
        let values = dailyRestingHR.map(\.bpm)
        guard let minVal = values.min(), let maxVal = values.max() else { return 40...100 }
        let padding = max(2, (maxVal - minVal) * 0.2)
        return (minVal - padding)...(maxVal + padding)
    }

    private var rangeChartDomain: ClosedRange<Double> {
        let mins = dailyHRRange.map(\.min)
        let maxs = dailyHRRange.map(\.max)
        guard let lo = mins.min(), let hi = maxs.max() else { return 40...180 }
        let padding = max(5, (hi - lo) * 0.1)
        return (lo - padding)...(hi + padding)
    }

    private var hrvChartDomain: ClosedRange<Double> {
        let values = dailyHRV.map(\.ms)
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...100 }
        let padding = max(5, (maxVal - minVal) * 0.2)
        return max(0, minVal - padding)...(maxVal + padding)
    }

    // MARK: - Helpers

    private func hrvInterpretation(_ ms: Double) -> String {
        if ms >= 50 { return "Good recovery capacity" }
        if ms >= 30 { return "Moderate — consider recovery days" }
        return "Low — prioritize rest and recovery"
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthKitManager.shared
        let fetchDays = max(dayCount, 14)
        async let hrData = hk.fetchDailyRestingHeartRate(days: fetchDays)
        async let rangeData = hk.fetchDailyHeartRateRange(days: min(dayCount, 30))
        async let hrvData = hk.fetchDailyHRV(days: fetchDays)
        async let statsData = hk.fetchHeartRateStats(for: .now)
        async let restingData = hk.fetchRestingHeartRate(for: .now)
        async let hrvToday = hk.fetchHRV(for: .now)
        dailyRestingHR = (try? await hrData) ?? []
        dailyHRRange = (try? await rangeData) ?? []
        dailyHRV = (try? await hrvData) ?? []
        todayStats = try? await statsData
        todayResting = try? await restingData
        todayHRV = try? await hrvToday
    }

    // MARK: - Shared Helpers

    private func statColumn(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value) \(unit)")
    }

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
