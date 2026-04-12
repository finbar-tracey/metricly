import SwiftUI
import Charts

struct SleepDetailView: View {
    @State private var dailySleep: [(date: Date, minutes: Double)] = []
    @State private var todaySleep: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]) = (0, nil, nil, [])
    @State private var timeRange: TimeRange = .week
    @State private var isLoading = true

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
    }

    private var dayCount: Int {
        switch timeRange {
        case .week: return 7
        case .month: return 30
        }
    }

    private var averageSleep: Double {
        guard !dailySleep.isEmpty else { return 0 }
        return dailySleep.map(\.minutes).reduce(0, +) / Double(dailySleep.count)
    }

    private var sleepQualityColor: Color {
        let hours = todaySleep.totalMinutes / 60
        if hours >= 7 { return .green }
        if hours >= 6 { return .yellow }
        if hours > 0 { return .orange }
        return .secondary
    }

    var body: some View {
        List {
            // Last night summary
            Section {
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(.quaternary, lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(1.0, todaySleep.totalMinutes / 480))
                            .stroke(sleepQualityColor.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 2) {
                            Text(HealthFormatters.formatSleepShort(todaySleep.totalMinutes))
                                .font(.title.bold())
                            Text("Last Night")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 110, height: 110)

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
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            // Sleep stages
            if !todaySleep.stages.isEmpty {
                Section("Sleep Stages") {
                    stageBreakdown
                }
            }

            // Duration trend
            Section("Duration Trend") {
                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                if !dailySleep.isEmpty {
                    Chart(dailySleep, id: \.date) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Hours", point.minutes / 60)
                        )
                        .foregroundStyle(.indigo.gradient)
                        .cornerRadius(4)
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

            Section("Stats") {
                statsRow("Average", value: HealthFormatters.formatSleepShort(averageSleep))
                statsRow("Best Night", value: HealthFormatters.formatSleepShort(dailySleep.map(\.minutes).max() ?? 0))
                statsRow("Nights Tracked", value: "\(dailySleep.count)")
            }
        }
        .navigationTitle("Sleep")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    // MARK: - Stage Breakdown

    private var stageBreakdown: some View {
        let grouped = Dictionary(grouping: todaySleep.stages) { $0.type }
        let stageOrder: [SleepStage.StageType] = [.deep, .core, .rem, .awake]
        let totalMinutes = todaySleep.stages.reduce(0.0) { $0 + $1.durationMinutes }

        return VStack(spacing: 12) {
            // Horizontal bar
            if totalMinutes > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(stageOrder, id: \.rawValue) { stageType in
                            let minutes = grouped[stageType]?.reduce(0.0) { $0 + $1.durationMinutes } ?? 0
                            let fraction = minutes / totalMinutes
                            if fraction > 0 {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(stageType.color)
                                    .frame(width: max(4, geo.size.width * fraction))
                            }
                        }
                    }
                }
                .frame(height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Legend
            HStack(spacing: 16) {
                ForEach(stageOrder, id: \.rawValue) { stageType in
                    let minutes = grouped[stageType]?.reduce(0.0) { $0 + $1.durationMinutes } ?? 0
                    if minutes > 0 {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(stageType.color)
                                .frame(width: 8, height: 8)
                            Text("\(stageType.rawValue) \(HealthFormatters.formatSleepShort(minutes))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthKitManager.shared
        async let sleepData = hk.fetchDailySleep(days: dayCount)
        async let todayData = hk.fetchSleep(for: .now)
        dailySleep = (try? await sleepData) ?? []
        todaySleep = (try? await todayData) ?? (0, nil, nil, [])
    }

    // MARK: - Formatting



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
