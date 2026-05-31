import SwiftUI
import SwiftData
import UIKit

struct CreatineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreatineEntry.date, order: .reverse) private var entries: [CreatineEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var undoEntry: CreatineEntry?
    @State private var undoWorkItem: DispatchWorkItem?
    @State private var historyRange: CreatineEngine.HistoryRange = .week
    @State private var historyScaffoldTimeRange: DetailTimeRange = .week

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var dose: Double { settings.creatineLoadingPhase ? 5.0 : settings.creatineDailyDose }
    private var isLoadingPhase: Bool { settings.creatineLoadingPhase }
    private var loadingDosesPerDay: Int { 4 }
    private var dailyTargetGrams: Double { isLoadingPhase ? 20.0 : settings.creatineDailyDose }

    private var todayEntries: [CreatineEntry] {
        CreatineEngine.todayEntries(from: entries)
    }
    private var todayTotalGrams: Double { CreatineEngine.todayTotalGrams(todayEntries: todayEntries) }
    private var hasTakenToday: Bool { CreatineEngine.hasTakenToday(todayEntries: todayEntries) }
    private var todayComplete: Bool {
        CreatineEngine.todayComplete(todayTotalGrams: todayTotalGrams, dailyTargetGrams: dailyTargetGrams)
    }
    private var dosesRemainingToday: Int {
        CreatineEngine.dosesRemainingToday(
            isLoadingPhase: isLoadingPhase,
            loadingDosesPerDay: loadingDosesPerDay,
            todayEntryCount: todayEntries.count,
            todayComplete: todayComplete
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                CreatineTrackerSections.heroCard(
                    todayComplete: todayComplete,
                    isLoadingPhase: isLoadingPhase,
                    hasTakenToday: hasTakenToday,
                    dosesRemainingToday: dosesRemainingToday,
                    todayTotalGrams: todayTotalGrams,
                    dailyTargetGrams: dailyTargetGrams,
                    dose: dose,
                    todayEntryCount: todayEntries.count,
                    loadingDosesPerDay: loadingDosesPerDay,
                    onLog: logCreatine
                )
                if isLoadingPhase {
                    CreatineTrackerSections.loadingPhaseCard(
                        dose: dose,
                        loadingDosesPerDay: loadingDosesPerDay,
                        todayEntryCount: todayEntries.count
                    )
                }
                CreatineTrackerSections.streakCard(
                    currentStreak: CreatineEngine.currentStreak(entries: entries, hasTakenToday: hasTakenToday),
                    longestStreak: CreatineEngine.longestStreak(entries: entries),
                    totalDays: entries.count
                )
                CreatineTrackerSections.complianceCard(CreatineEngine.weeklyCompliance(entries: entries))
                CreatineTrackerSections.calendarCard(last28Days: CreatineEngine.lastNDayStatus(entries: entries, days: 28))
                CreatineTrackerSections.chartCard(
                    data: CreatineEngine.dailyGrams(entries: entries, days: 30),
                    dailyTargetGrams: dailyTargetGrams
                )
                CreatineTrackerSections.HistorySection(
                    historyRange: $historyRange,
                    scaffoldTimeRange: $historyScaffoldTimeRange,
                    entries: entries,
                    dailyTargetGrams: dailyTargetGrams
                )
                CreatineTrackerSections.recentHistoryCard(entries: entries)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Creatine")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if undoEntry != nil {
                UndoBar(icon: "pill.fill", message: "Logged \(String(format: "%.0f", undoEntry?.grams ?? 0))g creatine", color: .blue) {
                    if let entry = undoEntry {
                        modelContext.delete(entry)
                        undoWorkItem?.cancel()
                        undoEntry = nil
                    }
                }
            }
        }
    }

    private func logCreatine() {
        let entry = CreatineEntry(grams: dose)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    NavigationStack { CreatineTrackerView() }
        .modelContainer(for: [CreatineEntry.self, UserSettings.self], inMemory: true)
}
