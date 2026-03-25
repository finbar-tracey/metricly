import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(\.weightUnit) private var weightUnit
    @Query private var allExercises: [Exercise]
    let exerciseName: String

    private var history: [Exercise] {
        allExercises
            .filter { $0.name == exerciseName && !(($0.workout?.isTemplate) ?? true) && !$0.sets.isEmpty }
            .sorted { ($0.workout?.date ?? .distantPast) > ($1.workout?.date ?? .distantPast) }
    }

    private var bestSet: ExerciseSet? {
        history.flatMap(\.sets).max { $0.weight < $1.weight }
    }

    var body: some View {
        List {
            if let best = bestSet {
                Section {
                    HStack {
                        Label("Best", systemImage: "trophy.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Text("\(best.reps) reps @ \(weightUnit.format(best.weight))")
                            .font(.headline)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Personal best: \(best.reps) reps at \(weightUnit.format(best.weight))")
                }
            }

            if chartData.count >= 2 {
                Section {
                    progressionChart
                        .frame(height: 200)
                        .padding(.vertical, 8)
                } header: {
                    Text("Progression")
                }
            }

            Section {
                if history.isEmpty {
                    Text("No history yet for this exercise.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(history.prefix(10)) { exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            if let date = exercise.workout?.date {
                                Text(date, format: .dateTime.weekday(.wide).month().day())
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 12) {
                                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, s in
                                    VStack {
                                        Text("\(s.reps)")
                                            .font(.headline)
                                        Text(weightUnit.formatShort(s.weight))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(minWidth: 44)
                                    .padding(.vertical, 4)
                                    .padding(.horizontal, 6)
                                    .background(.fill, in: .rect(cornerRadius: 8))
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("Set \(index + 1): \(s.reps) reps at \(weightUnit.format(s.weight))")
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Recent Sessions")
            }
        }
        .navigationTitle(exerciseName)
    }

    // MARK: - Progression Chart

    private struct ChartPoint: Identifiable {
        let id = UUID()
        let date: Date
        let maxWeight: Double
    }

    private var chartData: [ChartPoint] {
        history.reversed().compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let maxW = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
            guard maxW > 0 else { return nil }
            return ChartPoint(date: date, maxWeight: maxW)
        }
    }

    private var progressionChart: some View {
        Chart(chartData) { point in
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Weight", weightUnit.display(point.maxWeight))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            PointMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Weight", weightUnit.display(point.maxWeight))
            )
            .symbolSize(30)
            .foregroundStyle(Color.accentColor)
        }
        .chartYAxisLabel(weightUnit.label)
        .chartYScale(domain: chartYDomain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weight progression, \(chartData.count) sessions")
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartData.map { weightUnit.display($0.maxWeight) }
        guard let minVal = weights.min(), let maxVal = weights.max() else {
            return 0...100
        }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }
}
