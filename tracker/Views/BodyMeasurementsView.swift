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

    private func displayLength(_ cm: Double) -> Double { isMetric ? cm : cm / 2.54 }
    private func toCm(_ displayValue: Double) -> Double { isMetric ? displayValue : displayValue * 2.54 }
    private func formatLength(_ cm: Double) -> String {
        "\(String(format: "%.1f", displayLength(cm))) \(lengthLabel)"
    }

    private var siteEntries: [BodyMeasurement] { allEntries.filter { $0.site == selectedSite } }
    private var chartEntries: [BodyMeasurement] { Array(siteEntries.suffix(90).reversed()) }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                sitePickerCard
                if !siteEntries.isEmpty { heroCard }
                logCard
                if !siteEntries.isEmpty {
                    statsCard
                    chartCard
                    historyCard
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

    // MARK: - Site Picker

    private var sitePickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Measurement Site", icon: "ruler.fill", color: .purple)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(BodyMeasurement.allSites, id: \.self) { site in
                        let count = allEntries.filter { $0.site == site }.count
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedSite = site }
                        } label: {
                            VStack(spacing: 2) {
                                Text(site).font(.caption.bold())
                                if count > 0 {
                                    Text("\(count)").font(.system(size: 9))
                                        .foregroundStyle(selectedSite == site ? .white.opacity(0.75) : .secondary)
                                }
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(selectedSite == site ? Color.purple : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(selectedSite == site ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.purple, Color.teal.opacity(0.8)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "ruler.fill")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedSite)
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        if let current = siteEntries.first {
                            Text(formatLength(current.value))
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                        }
                    }
                    Spacer()
                    if let change = valueChange {
                        let isIncrease = displayLength(change) > 0
                        HStack(spacing: 4) {
                            Image(systemName: isIncrease ? "arrow.up" : "arrow.down").font(.caption.bold())
                            Text(formatChange(change)).font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    heroStatCol("Lowest", value: lowestValue.map { formatLength($0) } ?? "—")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Highest", value: highestValue.map { formatLength($0) } ?? "—")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Entries", value: "\(siteEntries.count)")
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Log Card

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Measurement", icon: "plus.circle.fill", color: .purple)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Value (\(lengthLabel))", text: $newValue)
                        .keyboardType(.decimalPad).focused($isValueFocused).font(.subheadline)
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 16)

                Button { addEntry() } label: {
                    Label("Log Measurement", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(newValue.isEmpty ? Color(.systemFill) : Color.purple.opacity(0.9))
                        .foregroundStyle(newValue.isEmpty ? Color.secondary : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .disabled(newValue.isEmpty)
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Statistics", icon: "chart.bar.fill", color: .purple)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statTile("Current", value: siteEntries.first.map { formatLength($0.value) } ?? "—",
                         icon: "ruler.fill", color: .purple)
                statTile("Lowest", value: lowestValue.map { formatLength($0) } ?? "—",
                         icon: "arrow.down.circle.fill", color: .green)
                statTile("Highest", value: highestValue.map { formatLength($0) } ?? "—",
                         icon: "arrow.up.circle.fill", color: .red)
                if let change = valueChange {
                    let isIncrease = displayLength(change) > 0
                    statTile("30d Change", value: formatChange(change),
                             icon: isIncrease ? "arrow.up.right" : "arrow.down.right",
                             color: isIncrease ? .orange : .green)
                } else {
                    statTile("30d Change", value: "—", icon: "minus.circle", color: .secondary)
                }
            }
        }
        .appCard()
    }

    private func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold().monospacedDigit())
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Trend", icon: "chart.line.uptrend.xyaxis", color: .purple)
            Chart(chartEntries) { entry in
                LineMark(x: .value("Date", entry.date, unit: .day),
                         y: .value("Value", displayLength(entry.value)))
                    .interpolationMethod(.catmullRom).foregroundStyle(Color.purple)
                AreaMark(x: .value("Date", entry.date, unit: .day),
                         y: .value("Value", displayLength(entry.value)))
                    .interpolationMethod(.catmullRom).foregroundStyle(Color.purple.opacity(0.15).gradient)
                PointMark(x: .value("Date", entry.date, unit: .day),
                          y: .value("Value", displayLength(entry.value)))
                    .symbolSize(20).foregroundStyle(Color.purple)
            }
            .chartYAxisLabel(lengthLabel)
            .chartYScale(domain: chartYDomain)
            .frame(height: 200).padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(selectedSite) measurement trend, \(chartEntries.count) entries")
        }
        .appCard()
    }

    // MARK: - History Card

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "clock.fill", color: .secondary)

            if siteEntries.isEmpty {
                Text("No entries for \(selectedSite) yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(siteEntries.prefix(30).enumerated()), id: \.element.persistentModelID) { idx, entry in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                    .font(.subheadline)
                                Text(entry.date, format: .dateTime.year())
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            Text(formatLength(entry.value)).font(.subheadline.bold().monospacedDigit())
                            changeIndicator(for: entry)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .accessibilityElement(children: .combine)
                        .contextMenu {
                            Button(role: .destructive) { entryToDelete = entry } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if idx < min(siteEntries.count, 30) - 1 { Divider().padding(.leading, 16) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .appCard()
    }

    // MARK: - Computed

    private var chartYDomain: ClosedRange<Double> {
        let values = chartEntries.map { displayLength($0.value) }
        guard let minVal = values.min(), let maxVal = values.max() else { return 0...100 }
        let padding = Swift.max(0.5, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    private var lowestValue: Double? { siteEntries.map(\.value).min() }
    private var highestValue: Double? { siteEntries.map(\.value).max() }

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
        newValue = ""; selectedDate = .now; isValueFocused = false
    }
}

#Preview {
    NavigationStack { BodyMeasurementsView() }
        .modelContainer(for: BodyMeasurement.self, inMemory: true)
}
