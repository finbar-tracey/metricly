import SwiftUI
import SwiftData
import Charts

struct BodyWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var newWeight = ""
    @State private var selectedDate = Date.now
    @State private var entryToDelete: BodyWeightEntry?
    @FocusState private var isWeightFocused: Bool

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if !entries.isEmpty { heroCard }
                logCard
                if !entries.isEmpty {
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
                if let entry = entryToDelete { modelContext.delete(entry); entryToDelete = nil }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.orange, Color.orange.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Current Weight")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        if let current = entries.first {
                            Text(weightUnit.format(current.weight))
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                        }
                    }
                    Spacer()
                    if let change = weightChange {
                        let isGain = weightUnit.display(change) > 0
                        HStack(spacing: 4) {
                            Image(systemName: isGain ? "arrow.up" : "arrow.down").font(.caption.bold())
                            Text(formatChange(change)).font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    heroStatCol("Lowest", value: lowestWeight.map { weightUnit.format($0) } ?? "—")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Highest", value: highestWeight.map { weightUnit.format($0) } ?? "—")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Entries", value: "\(entries.count)")
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Log Card

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Weight", icon: "plus.circle.fill", color: .orange)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    TextField("Weight (\(weightUnit.label))", text: $newWeight)
                        .keyboardType(.decimalPad).focused($isWeightFocused).font(.subheadline)
                    Spacer()
                    DatePicker("", selection: $selectedDate, displayedComponents: .date).labelsHidden()
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 16)

                Button { addEntry() } label: {
                    Label("Log Weight", systemImage: "plus.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(newWeight.isEmpty ? Color(.systemFill) : Color.orange.opacity(0.9))
                        .foregroundStyle(newWeight.isEmpty ? Color.secondary : Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .disabled(newWeight.isEmpty)
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
            SectionHeader(title: "Statistics", icon: "chart.bar.fill", color: .orange)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statTile("Current", value: entries.first.map { weightUnit.format($0.weight) } ?? "—",
                         icon: "scalemass.fill", color: .orange)
                statTile("Lowest", value: lowestWeight.map { weightUnit.format($0) } ?? "—",
                         icon: "arrow.down.circle.fill", color: .green)
                statTile("Highest", value: highestWeight.map { weightUnit.format($0) } ?? "—",
                         icon: "arrow.up.circle.fill", color: .red)
                if let change = weightChange {
                    let isGain = weightUnit.display(change) > 0
                    statTile("30d Change", value: formatChange(change),
                             icon: isGain ? "arrow.up.right" : "arrow.down.right", color: isGain ? .red : .green)
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
            SectionHeader(title: "Trend", icon: "chart.line.uptrend.xyaxis", color: .orange)
            Chart(chartEntries) { entry in
                LineMark(x: .value("Date", entry.date, unit: .day),
                         y: .value("Weight", weightUnit.display(entry.weight)))
                    .interpolationMethod(.catmullRom).foregroundStyle(Color.orange)
                AreaMark(x: .value("Date", entry.date, unit: .day),
                         y: .value("Weight", weightUnit.display(entry.weight)))
                    .interpolationMethod(.catmullRom).foregroundStyle(Color.orange.opacity(0.15).gradient)
                PointMark(x: .value("Date", entry.date, unit: .day),
                          y: .value("Weight", weightUnit.display(entry.weight)))
                    .symbolSize(20).foregroundStyle(Color.orange)
            }
            .chartYAxisLabel(weightUnit.label)
            .chartYScale(domain: chartYDomain)
            .frame(height: 200).padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Body weight trend, \(chartEntries.count) entries")
        }
        .appCard()
    }

    // MARK: - History Card

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "clock.fill", color: .secondary)
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(30).enumerated()), id: \.element.persistentModelID) { idx, entry in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                                .font(.subheadline)
                            Text(entry.date, format: .dateTime.year())
                                .font(.caption2).foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Text(weightUnit.format(entry.weight))
                            .font(.subheadline.bold().monospacedDigit())
                        changeIndicator(for: entry)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .accessibilityElement(children: .combine)
                    .contextMenu {
                        Button(role: .destructive) { entryToDelete = entry } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if idx < min(entries.count, 30) - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Computed

    private var chartEntries: [BodyWeightEntry] { Array(entries.suffix(90).reversed()) }

    private var chartYDomain: ClosedRange<Double> {
        let weights = chartEntries.map { weightUnit.display($0.weight) }
        guard let minVal = weights.min(), let maxVal = weights.max() else { return 0...100 }
        let padding = Swift.max(1, (maxVal - minVal) * 0.15)
        return (minVal - padding)...(maxVal + padding)
    }

    private var lowestWeight: Double? { entries.map(\.weight).min() }
    private var highestWeight: Double? { entries.map(\.weight).max() }

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

    @ViewBuilder
    private func changeIndicator(for entry: BodyWeightEntry) -> some View {
        if let index = entries.firstIndex(where: { $0.persistentModelID == entry.persistentModelID }),
           index + 1 < entries.count {
            let diff = entry.weight - entries[index + 1].weight
            if abs(diff) > 0.05 {
                Image(systemName: diff > 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption).foregroundStyle(diff > 0 ? .red : .green)
            }
        }
    }

    private func addEntry() {
        guard let value = Double(newWeight), value > 0 else { return }
        let weightKg = weightUnit.toKg(value)
        let entry = BodyWeightEntry(date: selectedDate, weight: weightKg)
        modelContext.insert(entry)
        if settingsArray.first?.healthKitEnabled == true {
            Task { try? await HealthKitManager.shared.saveBodyWeight(weightKg, date: selectedDate) }
        }
        newWeight = ""; selectedDate = .now; isWeightFocused = false
    }
}
