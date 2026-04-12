import SwiftUI
import Charts

struct StepsDetailView: View {
    @State private var dailySteps: [(date: Date, steps: Double)] = []
    @State private var timeRange: TimeRange = .week
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

    private var average: Double {
        guard !dailySteps.isEmpty else { return 0 }
        return dailySteps.map(\.steps).reduce(0, +) / Double(dailySteps.count)
    }

    private var todaySteps: Double {
        dailySteps.last?.steps ?? 0
    }

    var body: some View {
        List {
            Section("Trend") {
                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)

                if !dailySteps.isEmpty {
                    Chart(dailySteps, id: \.date) { point in
                        BarMark(
                            x: .value("Date", point.date, unit: .day),
                            y: .value("Steps", point.steps)
                        )
                        .foregroundStyle(.green.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel("steps")
                    .frame(height: 200)
                    .padding(.vertical, 8)
                } else if !isLoading {
                    Text("No step data available.")
                        .foregroundStyle(.secondary)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                }
            }

            Section("Stats") {
                statsRow("Today", value: HealthFormatters.formatSteps(todaySteps))
                statsRow("Daily Average", value: HealthFormatters.formatSteps(average))
                statsRow("Best Day", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).max() ?? 0))
                statsRow("Total", value: HealthFormatters.formatSteps(dailySteps.map(\.steps).reduce(0, +)))
            }

            Section("History") {
                if dailySteps.isEmpty && !isLoading {
                    Text("No step data available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dailySteps.reversed(), id: \.date) { entry in
                        HStack {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.subheadline)
                            Spacer()
                            Text(HealthFormatters.formatSteps(entry.steps))
                                .font(.subheadline.bold().monospacedDigit())
                                .foregroundStyle(entry.steps >= 10_000 ? .green : .primary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Steps")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: timeRange) {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        dailySteps = (try? await HealthKitManager.shared.fetchDailySteps(days: dayCount)) ?? []
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
