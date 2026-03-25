import SwiftUI
import SwiftData
import Charts

struct VolumeChartView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    var body: some View {
        List {
            Section {
                if weeklyData.isEmpty {
                    Text("No workout data yet.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    chartView
                        .frame(height: 220)
                        .padding(.vertical, 8)
                }
            } header: {
                Text("Total Volume Per Week")
            } footer: {
                Text("Volume = sets \u{00D7} reps \u{00D7} weight. Only working sets are counted.")
            }

            if !weeklyData.isEmpty {
                Section {
                    statsRow("This Week", value: thisWeekVolume)
                    statsRow("Last Week", value: lastWeekVolume)
                    statsRow("Best Week", value: bestWeekVolume)
                    statsRow("Avg / Week", value: avgWeekVolume)
                } header: {
                    Text("Summary")
                }

                Section {
                    statsRow("Total Workouts", count: totalWorkouts)
                    statsRow("Total Sets", count: totalWorkingSets)
                } header: {
                    Text("All Time")
                }
            }
        }
        .navigationTitle("Volume")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chart

    private var chartView: some View {
        Chart(weeklyData) { week in
            BarMark(
                x: .value("Week", week.label),
                y: .value("Volume", weightUnit.display(week.volume))
            )
            .foregroundStyle(Color.accentColor.gradient)
            .cornerRadius(4)
        }
        .chartYAxisLabel(weightUnit.label)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                AxisValueLabel()
                    .font(.caption2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekly volume chart, \(weeklyData.count) weeks")
        .accessibilityValue(chartAccessibilitySummary)
    }

    private var chartAccessibilitySummary: String {
        weeklyData.map { "\($0.label): \(formatVolume($0.volume))" }.joined(separator: ", ")
    }

    // MARK: - Stats Rows

    private func statsRow(_ title: String, value: Double) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(formatVolume(value))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func statsRow(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Data

    private struct WeekData: Identifiable {
        let id = UUID()
        let weekStart: Date
        let label: String
        let volume: Double // in kg
    }

    private var weeklyData: [WeekData] {
        let calendar = Calendar.current
        guard let earliestDate = workouts.last?.date else { return [] }

        let now = Date.now
        let startOfThisWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now

        // Go back up to 8 weeks
        var weeks: [WeekData] = []
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        for i in (0..<8).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: startOfThisWeek) else { continue }
            guard let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) else { continue }

            if weekStart < calendar.date(byAdding: .weekOfYear, value: -1, to: earliestDate) ?? earliestDate {
                continue
            }

            let weekWorkouts = workouts.filter { $0.date >= weekStart && $0.date < weekEnd }
            let volume = calculateVolume(for: weekWorkouts)

            weeks.append(WeekData(
                weekStart: weekStart,
                label: formatter.string(from: weekStart),
                volume: volume
            ))
        }
        return weeks
    }

    private func calculateVolume(for workouts: [Workout]) -> Double {
        var total = 0.0
        for workout in workouts {
            for exercise in workout.exercises {
                for set in exercise.sets where !set.isWarmUp {
                    total += Double(set.reps) * set.weight
                }
            }
        }
        return total
    }

    private var thisWeekVolume: Double {
        weeklyData.last?.volume ?? 0
    }

    private var lastWeekVolume: Double {
        guard weeklyData.count >= 2 else { return 0 }
        return weeklyData[weeklyData.count - 2].volume
    }

    private var bestWeekVolume: Double {
        weeklyData.map(\.volume).max() ?? 0
    }

    private var avgWeekVolume: Double {
        let nonEmpty = weeklyData.filter { $0.volume > 0 }
        guard !nonEmpty.isEmpty else { return 0 }
        return nonEmpty.map(\.volume).reduce(0, +) / Double(nonEmpty.count)
    }

    private var totalWorkouts: Int {
        workouts.count
    }

    private var totalWorkingSets: Int {
        workouts.flatMap(\.exercises).flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    private func formatVolume(_ volumeKg: Double) -> String {
        let displayValue = weightUnit.display(volumeKg)
        if displayValue >= 1000 {
            return String(format: "%.1fk %@", displayValue / 1000, weightUnit.label)
        }
        return String(format: "%.0f %@", displayValue, weightUnit.label)
    }
}
