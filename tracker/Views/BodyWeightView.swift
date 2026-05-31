import SwiftUI
import SwiftData

struct BodyWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.weightUnit) private var weightUnit
    @Environment(\.appServices) private var appServices
    @Query(sort: \BodyWeightEntry.date, order: .reverse) private var entries: [BodyWeightEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var newWeight = ""
    @State private var selectedDate = Date.now
    @State private var entryToDelete: BodyWeightEntry?
    @State private var timeRange: DetailTimeRange = .month
    @FocusState private var isWeightFocused: Bool

    private var summary: BodyWeightEngine.Summary {
        BodyWeightEngine.summary(entries: entries)
    }

    private var chartEntries: [BodyWeightEntry] {
        BodyWeightEngine.chartEntries(from: entries, maxCount: max(timeRange.dayCount * 2, 90))
    }

    private var trend: [BodyWeightEngine.TrendPoint] {
        BodyWeightEngine.movingAverageTrend(chartEntries: chartEntries) { weightUnit.display($0) }
    }

    private var chartYDomain: ClosedRange<Double> {
        BodyWeightEngine.chartYDomain(displayWeights: chartEntries.map { weightUnit.display($0.weight) })
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                ScrollView {
                    LazyVStack(spacing: AppTheme.sectionSpacing) {
                        BodyWeightTrackerSections.logCard(
                            weightUnit: weightUnit,
                            newWeight: $newWeight,
                            selectedDate: $selectedDate,
                            isWeightFocused: $isWeightFocused,
                            onLog: addEntry
                        )
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .background(Color(.systemGroupedBackground))
            } else {
                MetricDetailScaffold(
                    navigationTitle: "Body Weight",
                    isLoading: false,
                    isEmpty: false,
                    loadingMessage: "",
                    emptyIcon: "scalemass.fill",
                    emptyTitle: "No Weight Logged",
                    emptySubtitle: "Log your first weigh-in to see trends.",
                    timeRange: $timeRange,
                    segmentColor: .orange,
                    showRangePicker: true,
                    hero: {
                        BodyWeightTrackerSections.heroCard(
                            entries: entries,
                            weightUnit: weightUnit,
                            summary: summary,
                            formatChange: formatChange
                        )
                    },
                    content: {
                        BodyWeightTrackerSections.logCard(
                            weightUnit: weightUnit,
                            newWeight: $newWeight,
                            selectedDate: $selectedDate,
                            isWeightFocused: $isWeightFocused,
                            onLog: addEntry
                        )
                        BodyWeightTrackerSections.statsCard(
                            entries: entries,
                            weightUnit: weightUnit,
                            summary: summary,
                            formatChange: formatChange
                        )
                        BodyWeightTrackerSections.trendCard(
                            chartEntries: chartEntries,
                            trend: trend,
                            weightUnit: weightUnit,
                            yDomain: chartYDomain
                        )
                        BodyWeightTrackerSections.historyCard(
                            entries: entries,
                            weightUnit: weightUnit,
                            onDelete: { entryToDelete = $0 }
                        )
                    }
                )
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
                if let entry = entryToDelete { modelContext.delete(entry); entryToDelete = nil }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        }
    }

    private func formatChange(_ changeKg: Double) -> String {
        let value = weightUnit.display(changeKg)
        let sign = value >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", value)) \(weightUnit.label)"
    }

    private func addEntry() {
        guard let value = Double(newWeight), value > 0 else { return }
        let weightKg = weightUnit.toKg(value)
        let entry = BodyWeightEntry(date: selectedDate, weight: weightKg)
        modelContext.insert(entry)
        if settingsArray.first?.healthKitEnabled == true {
            Task {
                do {
                    try await appServices.healthKit.saveBodyWeight(weightKg, date: selectedDate)
                } catch {
                    appServices.appErrorBus.report(message: "Couldn't save weight to Apple Health.", kind: .warning)
                }
            }
        }
        newWeight = ""
        selectedDate = .now
        isWeightFocused = false
    }
}
