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
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading && todayStats == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    heroCard
                    timeRangePicker
                    if let stats = todayStats {
                        zonesCard(stats: stats)
                    }
                    restingTrendCard
                    if !dailyHRRange.isEmpty {
                        hrRangeCard
                    }
                    if !dailyHRV.isEmpty {
                        hrvCard
                    }
                    if lastWeekAvgResting > 0 {
                        weeklyComparisonCard
                    }
                    statsCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color(red: 0.88, green: 0.15, blue: 0.25), Color(red: 0.95, green: 0.35, blue: 0.35).opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 220)
                .offset(x: 160, y: -70)

            VStack(alignment: .leading, spacing: 20) {
                // Top: icon + primary BPM
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.20))
                            .frame(width: 56, height: 56)
                        Image(systemName: "heart.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        if let resting = todayResting {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(resting))")
                                    .font(.system(size: 48, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                Text("bpm")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            Text("Resting Heart Rate")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.75))
                        } else if let stats = todayStats {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(Int(stats.avg))")
                                    .font(.system(size: 48, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                Text("bpm")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                            Text("Average Today")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white.opacity(0.75))
                        } else {
                            Text("No Data")
                                .font(.system(size: 32, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                }

                // Stat columns
                HStack(spacing: 0) {
                    if let stats = todayStats {
                        heroStatColumn(icon: "arrow.down.heart.fill", label: "Min", value: "\(Int(stats.min)) bpm")
                        Divider().frame(height: 32).overlay(.white.opacity(0.30))
                        heroStatColumn(icon: "arrow.up.heart.fill", label: "Max", value: "\(Int(stats.max)) bpm")
                        Divider().frame(height: 32).overlay(.white.opacity(0.30))
                    }
                    if let hrv = todayHRV {
                        heroStatColumn(icon: "waveform.path.ecg", label: "HRV", value: "\(Int(hrv)) ms")
                    } else {
                        heroStatColumn(icon: "waveform.path.ecg", label: "HRV", value: "—")
                    }
                    if let stats = todayStats {
                        Divider().frame(height: 32).overlay(.white.opacity(0.30))
                        heroStatColumn(icon: "arrow.up.arrow.down", label: "Range", value: "\(Int(stats.max - stats.min))")
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroStatColumn(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.80))
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
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
                                ? AnyShapeStyle(Color(red: 0.88, green: 0.15, blue: 0.25))
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                            in: Capsule()
                        )
                        .shadow(color: timeRange == range ? Color.red.opacity(0.35) : .clear, radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    // MARK: - Zones Card

    private func zonesCard(stats: (min: Double, max: Double, avg: Double)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Zones", icon: "heart.circle.fill", color: .red)

            let zones = heartRateZones(min: stats.min, max: stats.max, avg: stats.avg)
            VStack(spacing: 0) {
                ForEach(Array(zones.enumerated()), id: \.element.name) { idx, zone in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(zone.color.gradient)
                            .frame(width: 4, height: 36)
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
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(zone.color.opacity(0.15), in: Capsule())
                                .foregroundStyle(zone.color)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if idx < zones.count - 1 {
                        Divider().padding(.leading, 34)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Resting HR Trend Card

    private var restingTrendCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Resting Heart Rate", icon: "heart.fill", color: .red)

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

                if let trend = restingTrend {
                    HStack(spacing: 6) {
                        Image(systemName: trend <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(trend <= 0 ? .green : .orange)
                        Text("\(trend <= 0 ? "Improving" : "Increasing") — \(abs(Int(trend))) bpm vs start of period")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
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

    // MARK: - Daily Range Card

    private var hrRangeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Daily Range", icon: "arrow.up.arrow.down.circle.fill", color: .orange)

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

            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Circle().fill(.blue).frame(width: 7, height: 7)
                    Text("Min").font(.caption2).foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Circle().fill(.orange).frame(width: 7, height: 7)
                    Text("Max").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .appCard()
    }

    // MARK: - HRV Card

    private var hrvCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Variability", icon: "waveform.path.ecg", color: .purple)

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

            let avgHRV = dailyHRV.map(\.ms).reduce(0, +) / Double(dailyHRV.count)
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.purple)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Average \(Int(avgHRV)) ms")
                        .font(.subheadline.bold())
                    Text(hrvInterpretation(avgHRV))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .appCard()
    }

    // MARK: - Weekly Comparison Card

    private var weeklyComparisonCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Week vs Last Week", icon: "arrow.left.arrow.right", color: .red)

            let delta = thisWeekAvgResting - lastWeekAvgResting
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text("This Week")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(thisWeekAvgResting))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("bpm avg")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    // Lower resting HR is better → down arrow is green
                    Image(systemName: delta <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(delta <= 0 ? .green : .orange)
                    Text("\(abs(Int(delta))) bpm")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(delta <= 0 ? .green : .orange)
                }

                VStack(spacing: 4) {
                    Text("Last Week")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Text("\(Int(lastWeekAvgResting))")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("bpm avg")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
        .appCard()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "list.number", color: .secondary)

            VStack(spacing: 0) {
                statsRow("Current Resting", value: todayResting.map { "\(Int($0)) bpm" } ?? "—")
                Divider().padding(.leading, 16)
                statsRow("Average Resting", value: averageResting.map { "\(Int($0)) bpm" } ?? "—")
                Divider().padding(.leading, 16)
                statsRow("Lowest Resting", value: lowestResting.map { "\(Int($0)) bpm" } ?? "—")
                Divider().padding(.leading, 16)
                statsRow("Highest Resting", value: highestResting.map { "\(Int($0)) bpm" } ?? "—")
                if let avgHRV = averageHRV {
                    Divider().padding(.leading, 16)
                    statsRow("Average HRV", value: "\(Int(avgHRV)) ms")
                }
                Divider().padding(.leading, 16)
                statsRow("Data Points", value: "\(dailyRestingHR.count) days")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Heart Rate Zones

    private struct HRZone {
        let name: String
        let range: String
        let color: Color
        let isActive: Bool
    }

    private func heartRateZones(min: Double, max: Double, avg: Double) -> [HRZone] {
        let estimatedMax = 190.0
        let restZone = estimatedMax * 0.5
        let fatBurnLow = estimatedMax * 0.5
        let fatBurnHigh = estimatedMax * 0.7
        let cardioLow = estimatedMax * 0.7
        let cardioHigh = estimatedMax * 0.85
        let peakLow = estimatedMax * 0.85

        return [
            HRZone(name: "Rest", range: "< \(Int(restZone)) bpm", color: .blue, isActive: min < restZone),
            HRZone(name: "Fat Burn", range: "\(Int(fatBurnLow))–\(Int(fatBurnHigh)) bpm", color: .green, isActive: max >= fatBurnLow && min <= fatBurnHigh),
            HRZone(name: "Cardio", range: "\(Int(cardioLow))–\(Int(cardioHigh)) bpm", color: .yellow, isActive: max >= cardioLow && min <= cardioHigh),
            HRZone(name: "Peak", range: "> \(Int(peakLow)) bpm", color: .red, isActive: max >= peakLow)
        ]
    }

    // MARK: - Computed Properties

    private var averageResting: Double? {
        guard !dailyRestingHR.isEmpty else { return nil }
        return dailyRestingHR.map(\.bpm).reduce(0, +) / Double(dailyRestingHR.count)
    }

    private var lowestResting: Double? { dailyRestingHR.map(\.bpm).min() }
    private var highestResting: Double? { dailyRestingHR.map(\.bpm).max() }

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
}
