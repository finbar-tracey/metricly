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
                    LoadingStateView("Loading heart rate…")
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    heroCard
                    HStack {
                        CapsuleSegmentPicker(options: TimeRange.allCases, selection: $timeRange,
                                             activeColor: Color(red: 0.88, green: 0.15, blue: 0.25))
                        Spacer()
                    }
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
        HeroCard(palette: AppTheme.Gradients.strain) {
            VStack(alignment: .leading, spacing: 20) {
                // Top: icon + primary BPM
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 60, height: 60)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "heart.fill")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        if let resting = todayResting {
                            Text("Resting Heart Rate")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                AnimatedInt(
                                    value: Int(resting),
                                    font: .system(size: 54, weight: .black, design: .rounded),
                                    color: .white
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                Text("bpm")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        } else if let stats = todayStats {
                            Text("Average Today")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                AnimatedInt(
                                    value: Int(stats.avg),
                                    font: .system(size: 54, weight: .black, design: .rounded),
                                    color: .white
                                )
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                Text("bpm")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
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
                        HeroStatCol(value: "\(Int(stats.min)) bpm", label: "Min", icon: "arrow.down.heart.fill")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                        HeroStatCol(value: "\(Int(stats.max)) bpm", label: "Max", icon: "arrow.up.heart.fill")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                    }
                    if let hrv = todayHRV {
                        HeroStatCol(value: "\(Int(hrv)) ms", label: "HRV", icon: "waveform.path.ecg")
                    } else {
                        HeroStatCol(value: "—", label: "HRV", icon: "waveform.path.ecg")
                    }
                    if let stats = todayStats {
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 36)
                        HeroStatCol(value: "\(Int(stats.max - stats.min))", label: "Range", icon: "arrow.up.arrow.down")
                    }
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
    }

    // MARK: - Zones Card

    private func zonesCard(stats: (min: Double, max: Double, avg: Double)) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Zones", icon: "heart.circle.fill", color: .red)

            let zones = heartRateZones(min: stats.min, max: stats.max, avg: stats.avg)
            VStack(spacing: 0) {
                ForEach(Array(zones.enumerated()), id: \.element.name) { idx, zone in
                    HStack(spacing: 14) {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [zone.color, zone.color.opacity(0.6)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 5, height: 42)
                            .shadow(color: zone.color.opacity(0.40), radius: 4, x: 0, y: 0)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(zone.name)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text(zone.range)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if zone.isActive {
                            Text("ACTIVE")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .tracking(0.5)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    LinearGradient(
                                        colors: [zone.color, zone.color.opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    in: Capsule()
                                )
                                .foregroundStyle(.white)
                                .shadow(color: zone.color.opacity(0.40), radius: 5, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if idx < zones.count - 1 {
                        Divider().padding(.leading, 35)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
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
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.red.opacity(0.55),
                                Color.red.opacity(0.22),
                                Color.red.opacity(0.02)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.red, Color(red: 0.85, green: 0.20, blue: 0.30)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.red.opacity(0.30), radius: 5, y: 2)

                    PointMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("BPM", point.bpm)
                    )
                    .symbolSize(36)
                    .foregroundStyle(Color.red)
                    .annotation(position: .overlay) {
                        Circle().fill(.white).frame(width: 4, height: 4)
                    }
                }
                .chartYAxisLabel("bpm")
                .chartYScale(domain: restingChartDomain)
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

                if let trend = restingTrend {
                    HStack(spacing: 7) {
                        Image(systemName: trend <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(trend <= 0 ? .green : .orange)
                        Text("\(trend <= 0 ? "Improving" : "Increasing") — \(abs(Int(trend))) bpm vs start of period")
                            .font(.caption.weight(.semibold))
                        Spacer()
                    }
                    .foregroundStyle(trend <= 0 ? .green : .orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background((trend <= 0 ? Color.green : Color.orange).opacity(0.12), in: Capsule())
                    .overlay(Capsule().stroke((trend <= 0 ? Color.green : Color.orange).opacity(0.20), lineWidth: 0.5))
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.55), Color.red.opacity(0.30)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(5)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Min", point.min)
                )
                .symbolSize(36)
                .foregroundStyle(Color.blue)
                .annotation(position: .overlay) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                }

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Max", point.max)
                )
                .symbolSize(36)
                .foregroundStyle(Color.orange)
                .annotation(position: .overlay) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                }
            }
            .chartYAxisLabel("bpm")
            .chartYScale(domain: rangeChartDomain)
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
            .frame(height: 200)

            HStack(spacing: 16) {
                HStack(spacing: 5) {
                    Circle().fill(.blue).frame(width: 8, height: 8)
                        .shadow(color: .blue.opacity(0.5), radius: 3)
                    Text("MIN")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    Circle().fill(.orange).frame(width: 8, height: 8)
                        .shadow(color: .orange.opacity(0.5), radius: 3)
                    Text("MAX")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.purple.opacity(0.55),
                            Color.purple.opacity(0.22),
                            Color.purple.opacity(0.02)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("HRV", point.ms)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, AppTheme.Signal.focus],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: Color.purple.opacity(0.30), radius: 5, y: 2)

                PointMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("HRV", point.ms)
                )
                .symbolSize(36)
                .foregroundStyle(Color.purple)
                .annotation(position: .overlay) {
                    Circle().fill(.white).frame(width: 4, height: 4)
                }
            }
            .chartYAxisLabel("ms")
            .chartYScale(domain: hrvChartDomain)
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
            .frame(height: 180)

            let avgHRV = dailyHRV.map(\.ms).reduce(0, +) / Double(dailyHRV.count)
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.purple, AppTheme.Signal.focus],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 42, height: 42)
                        .shadow(color: .purple.opacity(0.40), radius: 6, y: 3)
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Average \(Int(avgHRV)) ms")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
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
                VStack(spacing: 5) {
                    Text("THIS WEEK")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text("\(Int(thisWeekAvgResting))")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.red)
                    Text("bpm avg")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    // Lower resting HR is better → down arrow is green
                    Image(systemName: delta <= 0 ? "arrow.down.right.circle.fill" : "arrow.up.right.circle.fill")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(
                            LinearGradient(
                                colors: delta <= 0 ? [.green, AppTheme.Signal.recoveryShade]
                                                   : [.orange, AppTheme.Signal.actionOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Circle()
                        )
                        .shadow(color: (delta <= 0 ? Color.green : Color.orange).opacity(0.40), radius: 6, y: 3)
                    Text("\(abs(Int(delta))) bpm")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(delta <= 0 ? .green : .orange)
                }

                VStack(spacing: 5) {
                    Text("LAST WEEK")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.secondary)
                    Text("\(Int(lastWeekAvgResting))")
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("bpm avg")
                        .font(.caption2.weight(.semibold))
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
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
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
        let hk = HealthDataCache.shared
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
