import SwiftUI
import SwiftData
import Charts

struct BodyMeasurementsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query(sort: \BodyMeasurement.date, order: .reverse) private var allEntries: [BodyMeasurement]

    @State private var selectedSite = "Waist"
    @State private var newValue = ""
    @State private var selectedDate = Date.now
    @State private var entryToDelete: BodyMeasurement?
    @FocusState private var isValueFocused: Bool

    private var isMetric: Bool { weightUnit == .kg }
    private var lengthLabel: String { isMetric ? "cm" : "in" }

    private func displayLength(_ cm: Double) -> Double {
        isMetric ? cm : cm / 2.54
    }

    private func toCm(_ displayValue: Double) -> Double {
        isMetric ? displayValue : displayValue * 2.54
    }

    private func formatLength(_ cm: Double) -> String {
        let value = displayLength(cm)
        return "\(String(format: "%.1f", value)) \(lengthLabel)"
    }

    private var siteEntries: [BodyMeasurement] {
        allEntries.filter { $0.site == selectedSite }
    }

    private var chartEntries: [BodyMeasurement] {
        Array(siteEntries.suffix(90).reversed())
    }

    var body: some View {
        List {
            // Site picker
            Section {
                Picker("Measurement Site", selection: $selectedSite) {
                    ForEach(BodyMeasurement.allSites, id: \.self) { site in
                        Text(site).tag(site)
                    }
                }
            }

            if !chartEntries.isEmpty {
                Section {
                    chartView
                        .frame(height: 200)
                        .padding(.vertical, 8)
                } header: {
                    Text("Trend")
                }

                Section {
                    statsRow("Current", value: siteEntries.first.map { formatLength($0.value) } ?? "—")
                    statsRow("Lowest", value: lowestValue.map { formatLength($0) } ?? "—")
                    statsRow("Highest", value: highestValue.map { formatLength($0) } ?? "—")
                    if let change = valueChange {
                        statsRow("Change (30d)", value: formatChange(change))
                    }
                } header: {
                    Text("Stats")
                }
            }

            Section {
                HStack {
                    TextField("Value (\(lengthLabel))", text: $newValue)
                        .keyboardType(.decimalPad)
                        .focused($isValueFocused)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .labelsHidden()
                }
                Button {
                    addEntry()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log Measurement")
                    }
                }
                .disabled(newValue.isEmpty)
            } header: {
                Text("Log")
            }

            Section {
                if siteEntries.isEmpty {
                    Text("No entries for \(selectedSite) yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(siteEntries.prefix(30)) { entry in
                        HStack {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.subheadline)
                            Spacer()
                            Text(formatLength(entry.value))
                                .font(.subheadline.bold().monospacedDigit())
                            changeIndicator(for: entry)
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            let entries = Array(siteEntries.prefix(30))
                            entryToDelete = entries[index]
                        }
                    }
                }
            } header: {
                Text("History")
            }
        }
        .navigationTitle("Measurements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isValueFocused = false }
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

    private var chartView: some View {
        Chart(chartEntries) { entry in
            LineMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Value", displayLength(entry.value))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            AreaMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Value", displayLength(entry.value))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor.opacity(0.15).gradient)

            PointMark(
                x: .value("Date", entry.date, unit: .day),
                y: .value("Value", displayLength(entry.value))
            )
            .symbolSize(20)
            .foregroundStyle(Color.accentColor)
        }
        .chartYAxisLabel(lengthLabel)
        .chartYScale(domain: chartYDomain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(selectedSite) measurement trend, \(chartEntries.count) entries")
    }

    private var chartYDomain: ClosedRange<Double> {
        let values = chartEntries.map { displayLength($0.value) }
        guard let minVal = values.min(), let maxVal = values.max() else {
            return 0...100
        }
        let padding = Swift.max(0.5, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    // MARK: - Stats

    private var lowestValue: Double? {
        siteEntries.map(\.value).min()
    }

    private var highestValue: Double? {
        siteEntries.map(\.value).max()
    }

    private var valueChange: Double? {
        guard let latest = siteEntries.first else { return nil }
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .distantPast
        guard let oldest = siteEntries.last(where: { $0.date <= thirtyDaysAgo }) ?? siteEntries.last,
              oldest.persistentModelID != latest.persistentModelID else { return nil }
        return latest.value - oldest.value
    }

    private func formatChange(_ changeCm: Double) -> String {
        let value = displayLength(changeCm)
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) \(lengthLabel)"
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
    private func changeIndicator(for entry: BodyMeasurement) -> some View {
        let entries = siteEntries
        if let index = entries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }),
           index + 1 < entries.count {
            let previous = entries[index + 1]
            let diff = entry.value - previous.value
            if abs(diff) > 0.1 {
                Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
                    .foregroundStyle(diff > 0 ? .orange : .green)
            }
        }
    }

    // MARK: - Actions

    private func addEntry() {
        guard let value = Double(newValue), value > 0 else { return }
        let cm = toCm(value)
        let entry = BodyMeasurement(date: selectedDate, site: selectedSite, value: cm)
        modelContext.insert(entry)
        newValue = ""
        selectedDate = .now
        isValueFocused = false
    }
}

#Preview {
    NavigationStack {
        BodyMeasurementsView()
    }
    .modelContainer(for: BodyMeasurement.self, inMemory: true)
}
