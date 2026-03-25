import SwiftUI
import SwiftData
import Charts

struct BodyWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]

    @State private var newWeight = ""
    @State private var selectedDate = Date.now
    @State private var entryToDelete: BodyWeightEntry?
    @FocusState private var isWeightFocused: Bool

    var body: some View {
        List {
            if !chartEntries.isEmpty {
                Section {
                    chartView
                        .frame(height: 200)
                        .padding(.vertical, 8)
                } header: {
                    Text("Trend")
                }

                Section {
                    statsRow("Current", value: entries.first.map { weightUnit.format($0.weight) } ?? "—")
                    statsRow("Lowest", value: lowestWeight.map { weightUnit.format($0) } ?? "—")
                    statsRow("Highest", value: highestWeight.map { weightUnit.format($0) } ?? "—")
                    if let change = weightChange {
                        statsRow("Change (30d)", value: formatChange(change))
                    }
                } header: {
                    Text("Stats")
                }
            }

            Section {
                HStack {
                    TextField("Weight (\(weightUnit.label))", text: $newWeight)
                        .keyboardType(.decimalPad)
                        .focused($isWeightFocused)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Button {
                    addEntry()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log Weight")
                    }
                }
                .disabled(newWeight.isEmpty)
            } header: {
                Text("Log")
            }

            Section {
                if entries.isEmpty {
                    Text("No entries yet. Log your weight above.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(entries.prefix(30)) { entry in
                        HStack {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.subheadline)
                            Spacer()
                            Text(weightUnit.format(entry.weight))
                                .font(.subheadline.bold().monospacedDigit())
                            changeIndicator(for: entry)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            let entriesPrefix = Array(entries.prefix(30))
                            entryToDelete = entriesPrefix[index]
                        }
                    }
                }
            } header: {
                Text("History")
            }
        }
        .navigationTitle("Body Weight")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isWeightFocused = false }
            }
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    modelContext.delete(entry)
                    entryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        }
    }

    // MARK: - Chart

    private var chartEntries: [BodyWeightEntry] {
        Array(entries.suffix(90).reversed())
    }

    private var chartView: some View {
        Chart(chartEntries) { entry in
            LineMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Weight", weightUnit.display(entry.weight))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            AreaMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Weight", weightUnit.display(entry.weight))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor.opacity(0.15).gradient)

            PointMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Weight", weightUnit.display(entry.weight))
            )
            .symbolSize(20)
            .foregroundStyle(Color.accentColor)
        }
        .chartYAxisLabel(weightUnit.label)
        .chartYScale(domain: chartYDomain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Body weight trend, \(chartEntries.count) entries")
    }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartEntries.map { weightUnit.display($0.weight) }
        guard let minVal = weights.min(), let maxVal = weights.max() else {
            return 0...100
        }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    // MARK: - Stats

    private var lowestWeight: Double? {
        entries.map(\.weight).min()
    }

    private var highestWeight: Double? {
        entries.map(\.weight).max()
    }

    private var weightChange: Double? {
        guard let latest = entries.first else { return nil }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        guard let oldest = entries.last(where: { $0.date <= thirtyDaysAgo }) ?? entries.last,
              oldest.persistentModelID != latest.persistentModelID else { return nil }
        return latest.weight - oldest.weight
    }

    private func formatChange(_ changeKg: Double) -> String {
        let value = weightUnit.display(changeKg)
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) \(weightUnit.label)"
    }

    private func statsRow(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    // MARK: - Change Indicator

    @ViewBuilder
    private func changeIndicator(for entry: BodyWeightEntry) -> some View {
        if let index = entries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }),
           index + 1 < entries.count {
            let previous = entries[index + 1]
            let diff = entry.weight - previous.weight
            if abs(diff) > 0.05 {
                Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(diff > 0 ? .red : .green)
            }
        }
    }

    // MARK: - Actions

    private func addEntry() {
        guard let value = Double(newWeight), value > 0 else { return }
        let weightKg = weightUnit.toKg(value)
        let entry = BodyWeightEntry(date: selectedDate, weight: weightKg)
        modelContext.insert(entry)
        newWeight = ""
        selectedDate = .now
        isWeightFocused = false
    }
}
