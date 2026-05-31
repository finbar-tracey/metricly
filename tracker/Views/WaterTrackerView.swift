import SwiftUI
import SwiftData

struct WaterTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaterEntry.date, order: .reverse) private var allEntries: [WaterEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var customMl = ""
    @FocusState private var isMlFocused: Bool
    @State private var timeRange: DetailTimeRange = .week
    @State private var undoEntry: WaterEntry?
    @State private var undoWorkItem: DispatchWorkItem?

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var goalMl: Double { Double(settings.dailyWaterGoalMl) }

    private var todayEntries: [WaterEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= start }
    }

    private var todayTotalMl: Double { todayEntries.reduce(0) { $0 + $1.milliliters } }
    private var progress: Double { min(1.0, todayTotalMl / goalMl) }
    private var dayCount: Int { min(timeRange.dayCount, 30) }

    private var hydrationStreak: Int {
        WaterTrackerSections.hydrationStreak(
            allEntries: allEntries,
            todayTotalMl: todayTotalMl,
            goalMl: goalMl
        )
    }

    private var timeOfDayBreakdown: [WaterTrackerSections.TimeBlock] {
        WaterTrackerSections.timeOfDayBreakdown(todayEntries: todayEntries)
    }

    var body: some View {
        VStack(spacing: 0) {
            MetricDetailScaffold(
                navigationTitle: "Water",
                isLoading: false,
                isEmpty: false,
                loadingMessage: "",
                emptyIcon: "drop.fill",
                emptyTitle: "",
                emptySubtitle: "",
                timeRange: $timeRange,
                segmentColor: .cyan,
                showRangePicker: false,
                hero: {
                    WaterTrackerSections.heroCard(
                        todayTotalMl: todayTotalMl,
                        goalMl: goalMl,
                        progress: progress
                    )
                },
                content: {
                    WaterTrackerSections.quickAddCard(
                        customMl: $customMl,
                        isMlFocused: $isMlFocused,
                        onAdd: addEntry(ml:)
                    )
                    WaterTrackerSections.statsCard(
                        timeRange: timeRange,
                        stats: WaterTrackerSections.weeklyStats(
                            allEntries: allEntries,
                            days: dayCount,
                            goalMl: goalMl
                        ),
                        hydrationStreak: hydrationStreak
                    )
                    if hydrationStreak > 0 || todayTotalMl >= goalMl {
                        WaterTrackerSections.streakCard(hydrationStreak: hydrationStreak)
                    }
                    if !todayEntries.isEmpty {
                        WaterTrackerSections.timeOfDayCard(blocks: timeOfDayBreakdown)
                    }
                    WaterTrackerSections.chartCard(
                        timeRange: timeRange,
                        totals: WaterTrackerSections.dailyTotals(
                            allEntries: allEntries,
                            days: dayCount
                        ),
                        goalMl: goalMl,
                        onSelectRange: { timeRange = $0 }
                    )
                    if !todayEntries.isEmpty {
                        WaterTrackerSections.todayLogCard(todayEntries: todayEntries)
                    }
                }
            )
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMlFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if undoEntry != nil { undoBar }
        }
        .onAppear { drainWidgetPendingWater() }
    }

    private var undoBar: some View {
        UndoBar(icon: "drop.fill", message: "Added \(Int(undoEntry?.milliliters ?? 0)) ml", color: .cyan) {
            if let entry = undoEntry {
                modelContext.delete(entry)
                undoWorkItem?.cancel()
                undoEntry = nil
            }
        }
    }

    private func drainWidgetPendingWater() {
        guard let defaults = UserDefaults(suiteName: WidgetAppGroup.suiteName) else { return }
        let pending = defaults.double(forKey: "pendingWaterMl")
        guard pending > 0 else { return }
        defaults.set(0, forKey: "pendingWaterMl")
        addEntry(ml: pending)
    }

    private func addEntry(ml: Double) {
        let entry = WaterEntry(milliliters: ml)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        let today = Calendar.current.startOfDay(for: .now)
        let todayTotal = allEntries.filter { $0.date >= today }.reduce(0) { $0 + $1.milliliters } + ml
        MetriclySyncCoordinator.publishWater(
            todayMl: todayTotal,
            goalMl: Double(settings.dailyWaterGoalMl)
        )
        undoWorkItem?.cancel()
        withAnimation(.spring(duration: 0.3)) { undoEntry = entry }
        let work = DispatchWorkItem {
            withAnimation(.spring(duration: 0.3)) { undoEntry = nil }
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

#Preview {
    NavigationStack { WaterTrackerView() }
        .modelContainer(for: [WaterEntry.self, UserSettings.self], inMemory: true)
}
