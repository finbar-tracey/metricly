import SwiftUI
import SwiftData

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

    private func displayLength(_ cm: Double) -> Double { isMetric ? cm : cm / 2.54 }
    private func toCm(_ displayValue: Double) -> Double { isMetric ? displayValue : displayValue * 2.54 }
    private func formatLength(_ cm: Double) -> String {
        "\(String(format: "%.1f", displayLength(cm))) \(lengthLabel)"
    }
    private func formatChange(_ changeCm: Double) -> String {
        BodyMeasurementsEngine.formatChange(
            changeCm: changeCm,
            displayLength: displayLength,
            lengthLabel: lengthLabel
        )
    }

    private var siteEntries: [BodyMeasurement] {
        BodyMeasurementsEngine.siteEntries(allEntries: allEntries, site: selectedSite)
    }
    private var chartEntries: [BodyMeasurement] {
        BodyMeasurementsEngine.chartEntries(siteEntries: siteEntries)
    }
    private var chartYDomain: ClosedRange<Double> {
        BodyMeasurementsEngine.chartYDomain(
            displayLengths: chartEntries.map { displayLength($0.value) }
        )
    }
    private var valueChange: Double? {
        BodyMeasurementsEngine.valueChangeCm(siteEntries: siteEntries)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                BodyMeasurementsSections.sitePickerCard(
                    allEntries: allEntries,
                    selectedSite: $selectedSite
                )
                if !siteEntries.isEmpty {
                    BodyMeasurementsSections.heroCard(
                        selectedSite: selectedSite,
                        siteEntries: siteEntries,
                        valueChange: valueChange,
                        formatLength: formatLength,
                        formatChange: formatChange,
                        displayLength: displayLength
                    )
                }
                BodyMeasurementsSections.logCard(
                    lengthLabel: lengthLabel,
                    newValue: $newValue,
                    selectedDate: $selectedDate,
                    isValueFocused: $isValueFocused,
                    onAdd: addEntry
                )
                if !siteEntries.isEmpty {
                    BodyMeasurementsSections.statsCard(
                        siteEntries: siteEntries,
                        valueChange: valueChange,
                        formatLength: formatLength,
                        formatChange: formatChange,
                        displayLength: displayLength
                    )
                    BodyMeasurementsSections.chartCard(
                        selectedSite: selectedSite,
                        chartEntries: chartEntries,
                        chartYDomain: chartYDomain,
                        lengthLabel: lengthLabel,
                        displayLength: displayLength
                    )
                    BodyMeasurementsSections.historyCard(
                        selectedSite: selectedSite,
                        siteEntries: siteEntries,
                        formatLength: formatLength,
                        changeIndicator: changeIndicator,
                        onDelete: { entryToDelete = $0 }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
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
                if let entry = entryToDelete { modelContext.delete(entry); entryToDelete = nil }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        }
    }

    @ViewBuilder
    private func changeIndicator(for entry: BodyMeasurement) -> some View {
        let entries = siteEntries
        if let index = entries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }),
           index + 1 < entries.count {
            let diff = entry.value - entries[index + 1].value
            if abs(diff) > 0.1 {
                Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption).foregroundStyle(diff > 0 ? .orange : .green)
            }
        }
    }

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
    NavigationStack { BodyMeasurementsView() }
        .modelContainer(for: BodyMeasurement.self, inMemory: true)
}
