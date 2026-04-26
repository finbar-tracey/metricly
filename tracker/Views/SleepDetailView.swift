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
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading && todaySleep.totalMinutes == 0 {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if todaySleep.totalMinutes == 0 && !isLoading {
                    ContentUnavailableView(
                        "No Sleep Data",
                        systemImage: "bed.double.fill",
                        description: Text("No sleep data recorded for last night.")
                    )
                    .padding(.top, 60)
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
            .padding(.horizontal)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Section 1: Sleep Score Hero

    private var scoreSection: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.indigo, Color.indigo.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 220)
                .offset(x: 170, y: -65)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 130)
                .offset(x: 250, y: 60)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.20), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(1.0, todaySleep.totalMinutes / 480))
                            .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: sleepScore)
                        VStack(spacing: 1) {
                            Text("\(sleepScore)")
                                .font(.system(size: 30, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text(sleepScoreLabel)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white.opacity(0.80))
                        }
                    }
                    .frame(width: 86, height: 86)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sleep score \(sleepScore), \(sleepScoreLabel)")

                    VStack(alignment: .leading, spacing: 4) {
                        Text(HealthFormatters.formatSleepShort(todaySleep.totalMinutes))
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Last night")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }

                HStack(spacing: 0) {
                    if let inBed = todaySleep.inBed {
                        sleepStatColumn(
                            icon: "bed.double.fill",
                            label: "Bedtime",
                            value: inBed.formatted(.dateTime.hour().minute())
                        )
                    }
                    if let wake = todaySleep.wakeUp {
                        sleepStatColumn(
                            icon: "sun.horizon.fill",
                            label: "Wake",
                            value: wake.formatted(.dateTime.hour().minute())
                        )
                    }
                    if let eff = sleepEfficiency {
                        sleepStatColumn(
                            icon: "gauge.with.needle.fill",
                            label: "Efficiency",
                            value: "\(Int(eff))%"
                        )
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func sleepStatColumn(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.white.opacity(0.75))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.60))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Section 2: Sleep Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sleep Timeline", icon: "waveform.path.ecg", color: .indigo)

            VStack(spacing: 8) {
                Chart(todaySleep.stages) { stage in
                    RectangleMark(
                        xStart: .value("Start", stage.start),
                        xEnd: .value("End", stage.end),
                        yStart: .value("StageStart", stageDepth(stage.type)),
                        yEnd: .value("StageEnd", stageDepth(stage.type) + 0.8)
                    )
                    .foregroundStyle(stage.type.color)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
                .chartYScale(domain: -0.2...3.8)
                .chartYAxis {
                    AxisMarks(values: [0.4, 1.4, 2.4, 3.4]) { value in
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(stageLabelForDepth(v))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 1)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel(format: .dateTime.hour())
                            .font(.caption2)
                    }
                }
                .frame(height: 150)
            }
            .appCard()
        }
    }

    // MARK: - Section 3: Stage Breakdown Cards

    private var stageCardsSection: some View {
        let grouped = Dictionary(grouping: todaySleep.stages) { $0.type }
        let totalMinutes = todaySleep.stages.filter { $0.type != .awake }.reduce(0.0) { $0 + $1.durationMinutes }
        let stageOrder: [SleepStage.StageType] = [.deep, .core, .rem, .awake]

        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sleep Stages", icon: "chart.pie.fill", color: .indigo)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
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
        }
    }

    private func stageCard(type: SleepStage.StageType, minutes: Double, percentage: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(type.color)
                    .frame(width: 8, height: 8)
                Text(type.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                comparisonBadge(actual: percentage, recommended: recommendedRange(for: type))
            }

            Text(HealthFormatters.formatSleepShort(minutes))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .monospacedDigit()

            GradientProgressBar(value: percentage / 100, color: type.color, height: 6)

            Text("\(Int(percentage))% of sleep")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Section 4: Duration Trend

    private var durationTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Duration Trend", icon: "chart.bar.fill", color: .indigo)

            // Pill range picker
            HStack(spacing: 8) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            timeRange = range
                        }
                    } label: {
                        Text(range.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                timeRange == range
                                    ? AnyShapeStyle(Color.indigo)
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                in: Capsule()
                            )
                            .foregroundStyle(timeRange == range ? .white : .secondary)
                            .shadow(
                                color: timeRange == range ? Color.indigo.opacity(0.35) : .clear,
                                radius: 6, x: 0, y: 3
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if !chartSleep.isEmpty {
                Chart {
                    ForEach(chartSleep, id: \.date) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Hours", point.minutes / 60)
                        )
                        .foregroundStyle(Color.indigo.gradient)
                        .cornerRadius(5)
                    }
                    RuleMark(y: .value("Target", 8))
                        .lineStyle(StrokeStyle(dash: [5, 3]))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .annotation(position: .top, alignment: .trailing) {
                            Text("8h target")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                }
                .chartYAxisLabel("hours")
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(.secondary.opacity(0.3))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 200)
                .appCard()
            } else if !isLoading {
                Text("No sleep data available.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120)
                    .appCard()
            }
        }
    }

    // MARK: - Section 5: Weekly Comparison

    @ViewBuilder
    private var weeklyComparisonSection: some View {
        if lastWeekAvg > 0 {
            let delta = thisWeekAvg - lastWeekAvg
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "This Week vs Last Week", icon: "arrow.left.arrow.right", color: .indigo)

                HStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSleepShort(thisWeekAvg))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 6) {
                        Image(systemName: delta >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(delta >= 0 ? .green : .orange)
                        Text(HealthFormatters.formatSleepShort(abs(delta)))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(delta >= 0 ? .green : .orange)
                    }

                    VStack(spacing: 6) {
                        Text("Last Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(HealthFormatters.formatSleepShort(lastWeekAvg))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .appCard()
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Section 6: Bedtime Consistency

    @ViewBuilder
    private var consistencySection: some View {
        let consistencyData = detailedSleep.filter { $0.inBed != nil && $0.wakeUp != nil }
        if consistencyData.count >= 3 {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Bedtime Consistency", icon: "clock.fill", color: .indigo)

                VStack(spacing: 12) {
                    Chart(consistencyData, id: \.date) { day in
                        BarMark(
                            x: .value("Date", day.date, unit: .day),
                            yStart: .value("Bed", shiftedMinutes(day.inBed!)),
                            yEnd: .value("Wake", shiftedMinutes(day.wakeUp!))
                        )
                        .foregroundStyle(Color.indigo.opacity(0.20))
                        .cornerRadius(4)

                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Bed", shiftedMinutes(day.inBed!))
                        )
                        .foregroundStyle(Color.indigo)
                        .symbolSize(35)

                        PointMark(
                            x: .value("Date", day.date, unit: .day),
                            y: .value("Wake", shiftedMinutes(day.wakeUp!))
                        )
                        .foregroundStyle(Color.orange)
                        .symbolSize(35)
                    }
                    .chartYAxis {
                        AxisMarks(values: .stride(by: 60)) { value in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                                .foregroundStyle(.secondary.opacity(0.3))
                            AxisValueLabel {
                                if let mins = value.as(Double.self) {
                                    Text(formatShiftedMinutes(mins))
                                        .font(.caption2)
                                }
                            }
                        }
                    }
                    .frame(height: 170)

                    HStack(spacing: 16) {
                        HStack(spacing: 5) {
                            Circle().fill(Color.indigo).frame(width: 8, height: 8)
                            Text("Bedtime").font(.caption2).foregroundStyle(.secondary)
                        }
                        HStack(spacing: 5) {
                            Circle().fill(Color.orange).frame(width: 8, height: 8)
                            Text("Wake up").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .appCard()
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
            let debtColor: Color = debtHours > 5 ? .red : debtHours > 2 ? .orange : .green

            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Sleep Debt", icon: "moon.zzz.fill", color: .indigo)

                VStack(spacing: 16) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text(String(format: "%.1f", debtHours))
                                    .font(.system(size: 44, weight: .black, design: .rounded))
                                    .foregroundStyle(debtColor)
                                    .monospacedDigit()
                                Text("hrs")
                                    .font(.title3.weight(.semibold))
                                    .foregroundStyle(debtColor.opacity(0.75))
                                    .padding(.bottom, 6)
                            }
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
                        .frame(width: 58, height: 58)
                    }

                    GradientProgressBar(value: min(debtHours / 10, 1), color: debtColor, height: 8)

                    Text("Based on an 8-hour target. Each night short of the target adds to your debt.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .appCard()
            }
        }
    }

    // MARK: - Section 8: Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Stats", icon: "list.bullet.rectangle", color: .indigo)

            VStack(spacing: 0) {
                statsRow("Average", value: HealthFormatters.formatSleepShort(averageSleep))
                Divider().padding(.leading, 16)
                statsRow("Best Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).max() ?? 0))
                Divider().padding(.leading, 16)
                statsRow("Worst Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).min() ?? 0))
                Divider().padding(.leading, 16)
                statsRow("Nights Tracked", value: "\(dailySleep.count)")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
        }
    }

    // MARK: - Sleep Score

    private var sleepScore: Int { computeSleepScore() }

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
        return 15
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
        var deepScore: Double = 10
        if deepPct < 15 { deepScore = max(0, deepPct / 15 * 10) }
        else if deepPct > 20 { deepScore = max(4, 10 - (deepPct - 20) / 10 * 6) }
        var remScore: Double = 10
        if remPct < 20 { remScore = max(0, remPct / 20 * 10) }
        else if remPct > 25 { remScore = max(4, 10 - (remPct - 25) / 10 * 6) }
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
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
        } else if actual > recommended.upperBound {
            Text("High")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.yellow.opacity(0.15), in: Capsule())
                .foregroundStyle(.yellow)
        } else {
            Text("Normal")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        }
    }

    // MARK: - Consistency Helpers

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
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
