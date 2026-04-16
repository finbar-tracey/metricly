import SwiftUI
import Charts

struct SleepDetailView: View {
    @State private var dailySleep: [(date: Date, minutes: Double)] = []
    @State private var todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]) = (0, nil, nil, [])
    @State private var detailedSleep: [DailySleepDetail] = []
    @State private var timeRange: TimeRange = .week
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
            if isLoading && todaySleep.totalMinutes == 0 {
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            } else if todaySleep.totalMinutes == 0 && !isLoading {
                Section {
                    ContentUnavailableView(
                        "No Sleep Data",
                        systemImage: "bed.double.fill",
                        description: Text("No sleep data recorded for last night.")
                    )
                }
            } else {
                scoreSection
                if !todaySleep.stages.isEmpty {
                    timelineSection
                    stageCardsSection
                }
                durationTrendSection
                weeklyComparisonSection
                consistencySection
                sleepDebtSection
                statsSection
            }
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Section 1: Sleep Score

    private var scoreSection: some View {
        Section {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: min(1.0, todaySleep.totalMinutes / 480))
                        .stroke(sleepScoreColor.gradient, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: sleepScore)
                    VStack(spacing: 2) {
                        Text("\(sleepScore)")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text(sleepScoreLabel)
                            .font(.caption.bold())
                            .foregroundStyle(sleepScoreColor)
                    }
                }
                .frame(width: 130, height: 130)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Sleep score \(sleepScore) out of 100, \(sleepScoreLabel)")

                Text(HealthFormatters.formatSleepShort(todaySleep.totalMinutes))
                    .font(.title3.bold())

                HStack(spacing: 24) {
                    if let inBed = todaySleep.inBed {
                        VStack(spacing: 2) {
                            Image(systemName: "bed.double.fill")
                                .foregroundStyle(.indigo)
                            Text(inBed, format: .dateTime.hour().minute())
                                .font(.subheadline.bold().monospacedDigit())
                            Text("Bedtime")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let wake = todaySleep.wakeUp {
                        VStack(spacing: 2) {
                            Image(systemName: "sun.horizon.fill")
                                .foregroundStyle(.orange)
                            Text(wake, format: .dateTime.hour().minute())
                                .font(.subheadline.bold().monospacedDigit())
                            Text("Wake Up")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let efficiency = sleepEfficiency {
                        VStack(spacing: 2) {
                            Image(systemName: "gauge.with.needle.fill")
                                .foregroundStyle(.indigo)
                            Text("\(Int(efficiency))%")
                                .font(.subheadline.bold().monospacedDigit())
                            Text("Efficiency")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section 2: Sleep Timeline

    private var timelineSection: some View {
        Section("Sleep Timeline") {
            Chart(todaySleep.stages) { stage in
                RectangleMark(
                    xStart: .value("Start", stage.start),
                    xEnd: .value("End", stage.end),
                    yStart: .value("StageStart", stageDepth(stage.type)),
                    yEnd: .value("StageEnd", stageDepth(stage.type) + 0.8)
                )
                .foregroundStyle(stage.type.color)
                .clipShape(RoundedRectangle(cornerRadius: 2))
            }
            .chartYScale(domain: -0.2...3.8)
            .chartYAxis {
                AxisMarks(values: [0.4, 1.4, 2.4, 3.4]) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(stageLabelForDepth(v))
                                .font(.caption2)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .frame(height: 160)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section 3: Stage Breakdown Cards

    private var stageCardsSection: some View {
        let grouped = Dictionary(grouping: todaySleep.stages) { $0.type }
        let totalMinutes = todaySleep.stages.filter { $0.type != .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        let stageOrder: [SleepStage.StageType] = [.deep, .core, .rem, .awake]

        return Section("Sleep Stages") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(stageOrder, id: \.rawValue) { stageType in
                    let minutes = grouped[stageType]?.reduce(0.0) { $0 + $1.durationMinutes } ?? 0
                    if minutes > 0 {
                        let totalForPercentage = stageType == .awake
                            ? todaySleep.stages.reduce(0.0) { $0 + $1.durationMinutes }
                            : totalMinutes
                        let percentage = totalForPercentage > 0 ? (minutes / totalForPercentage) * 100 : 0
                        stageCard(type: stageType, minutes: minutes, percentage: percentage)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        }
    }

    private func stageCard(type: SleepStage.StageType, minutes: Double, percentage: Double) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle().fill(type.color).frame(width: 10, height: 10)
                Text(type.rawValue).font(.subheadline.bold())
                Spacer()
            }
            Text(HealthFormatters.formatSleepShort(minutes))
                .font(.title3.bold().monospacedDigit())
            HStack {
                Text("\(Int(percentage))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                comparisonBadge(actual: percentage, recommended: recommendedRange(for: type))
            }
            ProgressView(value: min(percentage, 100), total: 100)
                .tint(type.color)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section 4: Duration Trend

    private var durationTrendSection: some View {
        Section("Duration Trend") {
            Picker("Range", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

            if !chartSleep.isEmpty {
                Chart {
                    ForEach(chartSleep, id: \.date) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Hours", point.minutes / 60)
                        )
                        .foregroundStyle(.indigo.gradient)
                        .cornerRadius(4)
                    }
                    RuleMark(y: .value("Target", 8))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("8h")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxisLabel("hours")
                .frame(height: 200)
                .padding(.vertical, 8)
            } else if !isLoading {
                Text("No sleep data available.")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Section 5: Weekly Comparison

    @ViewBuilder
    private var weeklyComparisonSection: some View {
        if lastWeekAvg > 0 {
            Section("This Week vs Last Week") {
                HStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSleepShort(thisWeekAvg))
                            .font(.title3.bold().monospacedDigit())
                    }
                    .frame(maxWidth: .infinity)

                    let delta = thisWeekAvg - lastWeekAvg
                    VStack(spacing: 2) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.title3)
                            .foregroundStyle(delta >= 0 ? .green : .orange)
                        Text(HealthFormatters.formatSleepShort(abs(delta)))
                            .font(.caption.bold())
                            .foregroundStyle(delta >= 0 ? .green : .orange)
                    }

                    VStack(spacing: 4) {
                        Text("Last Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSleepShort(lastWeekAvg))
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

    // MARK: - Section 6: Bedtime Consistency

    @ViewBuilder
    private var consistencySection: some View {
        let consistencyData = detailedSleep.filter { $0.inBed != nil && $0.wakeUp != nil }
        if consistencyData.count >= 3 {
            Section("Bedtime Consistency") {
                Chart(consistencyData, id: \.date) { day in
                    BarMark(
                        x: .value("Date", day.date, unit: .day),
                        yStart: .value("Bed", shiftedMinutes(day.inBed!)),
                        yEnd: .value("Wake", shiftedMinutes(day.wakeUp!))
                    )
                    .foregroundStyle(.indigo.opacity(0.25))
                    .cornerRadius(4)

                    PointMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Bed", shiftedMinutes(day.inBed!))
                    )
                    .foregroundStyle(.indigo)
                    .symbolSize(30)

                    PointMark(
                        x: .value("Date", day.date, unit: .day),
                        y: .value("Wake", shiftedMinutes(day.wakeUp!))
                    )
                    .foregroundStyle(.orange)
                    .symbolSize(30)
                }
                .chartYAxis {
                    AxisMarks(values: .stride(by: 60)) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let mins = value.as(Double.self) {
                                Text(formatShiftedMinutes(mins))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
                .padding(.vertical, 8)

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Circle().fill(.indigo).frame(width: 8, height: 8)
                        Text("Bedtime").font(.caption2).foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        Circle().fill(.orange).frame(width: 8, height: 8)
                        Text("Wake up").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    // MARK: - Section 7: Sleep Debt

    @ViewBuilder
    private var sleepDebtSection: some View {
        if !detailedSleep.isEmpty {
            let targetMinutes = 480.0
            let totalDebt = detailedSleep.reduce(0.0) { debt, day in
                debt + max(0, targetMinutes - day.totalMinutes)
            }
            let debtHours = totalDebt / 60

            Section("Sleep Debt") {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.1fh", debtHours))
                                .font(.title.bold().monospacedDigit())
                                .foregroundStyle(debtHours > 5 ? .red : debtHours > 2 ? .orange : .green)
                            Text("accumulated over 7 days")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Gauge(value: min(debtHours, 10), in: 0...10) {
                            Image(systemName: "moon.zzz.fill")
                        }
                        .gaugeStyle(.accessoryCircular)
                        .tint(Gradient(colors: [.green, .yellow, .orange, .red]))
                        .frame(width: 60, height: 60)
                    }

                    Text("Based on an 8-hour target. Each night short of the target adds to your debt.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Section 8: Stats

    private var statsSection: some View {
        Section("Stats") {
            statsRow("Average", value: HealthFormatters.formatSleepShort(averageSleep))
            statsRow("Best Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).max() ?? 0))
            statsRow("Worst Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).min() ?? 0))
            statsRow("Nights Tracked", value: "\(dailySleep.count)")
        }
    }

    // MARK: - Sleep Score

    private var sleepScore: Int {
        computeSleepScore()
    }

    private var sleepScoreColor: Color {
        if sleepScore >= 85 { return .green }
        if sleepScore >= 70 { return .blue }
        if sleepScore >= 50 { return .yellow }
        return .orange
    }

    private var sleepScoreLabel: String {
        if sleepScore >= 85 { return "Excellent" }
        if sleepScore >= 70 { return "Good" }
        if sleepScore >= 50 { return "Fair" }
        return "Poor"
    }

    private func computeSleepScore() -> Int {
        let duration = durationScore()
        let stages = stageQualityScore()
        let consistency = consistencyScore()
        let efficiency = efficiencyScore()
        return min(100, max(0, duration + stages + consistency + efficiency))
    }

    private func durationScore() -> Int {
        let mins = todaySleep.totalMinutes
        if mins >= 420 && mins <= 540 { return 25 }
        if mins >= 360 && mins < 420 { return Int(15 + (mins - 360) / 60 * 10) }
        if mins >= 300 && mins < 360 { return Int(5 + (mins - 300) / 60 * 10) }
        if mins < 300 { return Int(max(0, mins / 300 * 5)) }
        if mins > 540 && mins <= 600 { return 20 }
        return 15 // oversleeping
    }

    private func stageQualityScore() -> Int {
        let sleepStages = todaySleep.stages
        guard !sleepStages.isEmpty else { return 15 }

        let totalSleep = sleepStages.filter { $0.type != .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        guard totalSleep > 0 else { return 15 }

        let deepMins = sleepStages.filter { $0.type == .deep }.reduce(0.0) { $0 + $1.durationMinutes }
        let remMins = sleepStages.filter { $0.type == .rem }.reduce(0.0) { $0 + $1.durationMinutes }
        let awakeMins = sleepStages.filter { $0.type == .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        let totalAll = totalSleep + awakeMins

        let deepPct = deepMins / totalSleep * 100
        let remPct = remMins / totalSleep * 100
        let awakePct = totalAll > 0 ? awakeMins / totalAll * 100 : 0

        // Deep: target 15-20%, max 10 pts
        var deepScore: Double = 10
        if deepPct < 15 { deepScore = max(0, deepPct / 15 * 10) }
        else if deepPct > 20 { deepScore = max(4, 10 - (deepPct - 20) / 10 * 6) }

        // REM: target 20-25%, max 10 pts
        var remScore: Double = 10
        if remPct < 20 { remScore = max(0, remPct / 20 * 10) }
        else if remPct > 25 { remScore = max(4, 10 - (remPct - 25) / 10 * 6) }

        // Awake: target <5%, max 5 pts
        var awakeScore: Double = 5
        if awakePct > 5 { awakeScore = max(0, 5 - (awakePct - 5) / 10 * 5) }

        return Int(deepScore + remScore + awakeScore)
    }

    private func consistencyScore() -> Int {
        let withTimes = detailedSleep.filter { $0.inBed != nil && $0.wakeUp != nil }
        guard withTimes.count >= 3 else { return 15 }

        let calendar = Calendar.current
        let bedMinutes = withTimes.compactMap { detail -> Double? in
            guard let bed = detail.inBed else { return nil }
            let h = calendar.component(.hour, from: bed)
            let m = calendar.component(.minute, from: bed)
            // Shift so 6PM=0 to handle midnight wrap
            let total = Double(h * 60 + m)
            return total >= 1080 ? total - 1080 : total + 360
        }
        let wakeMinutes = withTimes.compactMap { detail -> Double? in
            guard let wake = detail.wakeUp else { return nil }
            let h = calendar.component(.hour, from: wake)
            let m = calendar.component(.minute, from: wake)
            let total = Double(h * 60 + m)
            return total >= 1080 ? total - 1080 : total + 360
        }

        let bedStdDev = standardDeviation(bedMinutes)
        let wakeStdDev = standardDeviation(wakeMinutes)
        let avgDev = (bedStdDev + wakeStdDev) / 2

        if avgDev <= 30 { return 25 }
        if avgDev <= 60 { return Int(15 + (60 - avgDev) / 30 * 10) }
        if avgDev <= 90 { return Int(5 + (90 - avgDev) / 30 * 10) }
        return Int(max(0, 5 - (avgDev - 90) / 30 * 5))
    }

    private func efficiencyScore() -> Int {
        guard let eff = sleepEfficiency else { return 15 }
        if eff >= 90 { return 25 }
        if eff >= 85 { return 20 }
        if eff >= 80 { return 15 }
        if eff >= 75 { return 10 }
        return Int(max(0, eff / 75 * 10))
    }

    // MARK: - Computed Properties

    private var sleepEfficiency: Double? {
        guard let inBed = todaySleep.inBed, let wakeUp = todaySleep.wakeUp else { return nil }
        let timeInBed = wakeUp.timeIntervalSince(inBed) / 60
        guard timeInBed > 0 else { return nil }
        return (todaySleep.totalMinutes / timeInBed) * 100
    }

    private var averageSleep: Double {
        guard !dailySleep.isEmpty else { return 0 }
        return dailySleep.map(\.minutes).reduce(0, +) / Double(dailySleep.count)
    }

    private var chartSleep: [(date: Date, minutes: Double)] {
        Array(dailySleep.suffix(dayCount))
    }

    private var thisWeekAvg: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = dailySleep.filter { $0.date >= weekStart }
        guard !thisWeek.isEmpty else { return 0 }
        return thisWeek.map(\.minutes).reduce(0, +) / Double(thisWeek.count)
    }

    private var lastWeekAvg: Double {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let prevStart = calendar.date(byAdding: .day, value: -7, to: weekStart)!
        let lastWeek = dailySleep.filter { $0.date >= prevStart && $0.date < weekStart }
        guard !lastWeek.isEmpty else { return 0 }
        return lastWeek.map(\.minutes).reduce(0, +) / Double(lastWeek.count)
    }

    // MARK: - Timeline Helpers

    private func stageDepth(_ type: SleepStage.StageType) -> Double {
        switch type {
        case .deep: return 0
        case .core: return 1
        case .unspecified: return 1
        case .rem: return 2
        case .awake: return 3
        }
    }

    private func stageLabelForDepth(_ value: Double) -> String {
        switch value {
        case 0.4: return "Deep"
        case 1.4: return "Core"
        case 2.4: return "REM"
        case 3.4: return "Awake"
        default: return ""
        }
    }

    // MARK: - Stage Card Helpers

    private func recommendedRange(for type: SleepStage.StageType) -> ClosedRange<Double> {
        switch type {
        case .deep: return 15...20
        case .core: return 40...60
        case .rem: return 20...25
        case .awake: return 0...5
        case .unspecified: return 0...100
        }
    }

    @ViewBuilder
    private func comparisonBadge(actual: Double, recommended: ClosedRange<Double>) -> some View {
        if actual < recommended.lowerBound {
            Text("Low")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
        } else if actual > recommended.upperBound {
            Text("High")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.15), in: Capsule())
                .foregroundStyle(.yellow)
        } else {
            Text("Normal")
                .font(.caption2.bold())
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        }
    }

    // MARK: - Consistency Helpers

    /// Shift time to a 6PM-anchored scale so bedtimes near midnight don't wrap.
    /// 6PM → 0, midnight → 360, 6AM → 720, noon → 1080
    private func shiftedMinutes(_ date: Date) -> Double {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let total = Double(hour * 60 + minute)
        return total >= 1080 ? total - 1080 : total + 360
    }

    private func formatShiftedMinutes(_ shifted: Double) -> String {
        let actual = shifted >= 360 ? shifted - 360 : shifted + 1080
        let totalMins = Int(actual) % 1440
        let hour = totalMins / 60
        let displayHour = hour % 12 == 0 ? 12 : hour % 12
        let ampm = hour < 12 ? "AM" : "PM"
        return "\(displayHour) \(ampm)"
    }

    // MARK: - Math Helpers

    private func standardDeviation(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count)
        return variance.squareRoot()
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthKitManager.shared
        let fetchDays = max(dayCount, 14)
        async let sleepData = hk.fetchDailySleep(days: fetchDays)
        async let todayData = hk.fetchSleep(for: .now)
        async let detailedData = hk.fetchDailySleepDetailed(days: 7)
        dailySleep = (try? await sleepData) ?? []
        todaySleep = (try? await todayData) ?? (0, nil, nil, [])
        detailedSleep = (try? await detailedData) ?? []
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
