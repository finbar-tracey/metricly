import SwiftUI
import Charts

struct HeartRateDetailView: View {
    @State private var dailyRestingHR: [(date: Date, bpm: Double)] = []
    @State private var todayStats: (min: Double, max: Double, avg: Double)?
    @State private var timeRange: TimeRange = .month
    @State private var isLoading = true

    enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
        case threeMonths = "90D"
    }

    private var dayCount: Int {
        switch timeRange {
        case .week: return 7
        case .month: return 30
        case .threeMonths: return 90
        }
    }

    private var averageResting: Double? {
        guard !dailyRestingHR.isEmpty else { return nil }
        return dailyRestingHR.map(\.bpm).reduce(0, +) / Double(dailyRestingHR.count)
    }

    private var lowestResting: Double? {
        dailyRestingHR.map(\.bpm).min()
    }

    var body: some View {
        List {
            // Today's HR summary
            if let stats = todayStats {
                Section {
                    HStack(spacing: 0) {
                        statColumn(label: "Min", value: "\(Int(stats.min))", unit: "bpm", color: .blue)
                        Divider().frame(height: 40)
                        statColumn(label: "Avg", value: "\(Int(stats.avg))", unit: "bpm", color: .red)
                        Divider().frame(height: 40)
                        statColumn(label: "Max", value: "\(Int(stats.max))", unit: "bpm", color: .orange)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Today")
                }
            }

            // Resting HR trend
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
                    .chartYScale(domain: chartYDomain)
                    .frame(height: 200)
                    .padding(.vertical, 8)
                } else if !isLoading {
                    Text("No resting heart rate data available.")
                        .foregroundStyle(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Stats") {
                statsRow("Current Resting", value: dailyRestingHR.last.map { "\(Int($0.bpm)) bpm" } ?? "—")
                statsRow("Average Resting", value: averageResting.map { "\(Int($0)) bpm" } ?? "—")
                statsRow("Lowest Resting", value: lowestResting.map { "\(Int($0)) bpm" } ?? "—")
                statsRow("Data Points", value: "\(dailyRestingHR.count) days")
            }
        }
        .navigationTitle("Heart Rate")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = dailyRestingHR.map(\.bpm)
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 40...100
        }
        let padding = max(2, (maxVal - minVal) * 0.2)
        return (minVal - padding)...(maxVal + padding)
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let hk = HealthKitManager.shared
        async let hrData = hk.fetchDailyRestingHeartRate(days: dayCount)
        async let statsData = hk.fetchHeartRateStats(for: .now)
        dailyRestingHR = (try? await hrData) ?? []
        todayStats = try? await statsData
    }

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
