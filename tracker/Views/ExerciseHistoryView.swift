import SwiftUI
import SwiftData
import Charts

struct ExerciseHistoryView: View {
    @Environment(\.weightUnit) private var weightUnit
    @Query private var allExercises: [Exercise]
    let exerciseName: String
    @State private var showEstimated1RM = false

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

                    if let e1rm = currentEstimated1RM, e1rm > 0 {
                        HStack {
                            Label("Est. 1RM", systemImage: "arrow.up.right.circle")
                                .foregroundStyle(.purple)
                            Spacer()
                            Text(weightUnit.format(e1rm))
                                .font(.headline)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Estimated one rep max: \(weightUnit.format(e1rm))")
                    }
                }
            }

            if chartData.count >= 2 {
                Section {
                    Picker("Chart", selection: $showEstimated1RM) {
                        Text("Max Weight").tag(false)
                        Text("Est. 1RM").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .listRowSeparator(.hidden)

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
        let estimated1RM: Double
    }

    /// Epley formula: 1RM = weight × (1 + reps / 30)
    private func estimated1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 else { return weight }
        if reps == 1 { return weight }
        return weight * (1.0 + Double(reps) / 30.0)
    }

    private var chartData: [ChartPoint] {
        history.reversed().compactMap { exercise in
            guard let date = exercise.workout?.date else { return nil }
            let workingSets = exercise.sets.filter { !$0.isWarmUp }
            let maxW = workingSets.map(\.weight).max() ?? 0
            guard maxW > 0 else { return nil }
            let best1RM = workingSets.map { estimated1RM(weight: $0.weight, reps: $0.reps) }.max() ?? maxW
            return ChartPoint(date: date, maxWeight: maxW, estimated1RM: best1RM)
        }
    }

    private var currentEstimated1RM: Double? {
        guard let latest = chartData.last else { return nil }
        return latest.estimated1RM
    }

    private var progressionChart: some View {
        Chart(chartData) { point in
            let value = showEstimated1RM ? point.estimated1RM : point.maxWeight
            LineMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Weight", weightUnit.display(value))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(showEstimated1RM ? Color.purple : Color.accentColor)

            PointMark(
                x: .value("Date", point.date, unit: .day),
                y: .value("Weight", weightUnit.display(value))
            )
            .symbolSize(30)
            .foregroundStyle(showEstimated1RM ? Color.purple : Color.accentColor)
        }
        .chartYAxisLabel(weightUnit.label)
        .chartYScale(domain: chartYDomain)
        .animation(.easeInOut(duration: 0.3), value: showEstimated1RM)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(showEstimated1RM ? "Estimated 1RM" : "Weight") progression, \(chartData.count) sessions")
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartData.map { weightUnit.display(showEstimated1RM ? $0.estimated1RM : $0.maxWeight) }
        guard let minVal = weights.min(), let maxVal = weights.max() else {
            return 0...100
        }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }
}
