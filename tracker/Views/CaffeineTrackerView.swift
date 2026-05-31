import SwiftUI
import SwiftData
import UIKit

struct CaffeineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CaffeineEntry.date, order: .reverse) private var entries: [CaffeineEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var selectedSource = "Coffee"
    @State private var customMg = ""
    @State private var entryToDelete: CaffeineEntry?
    @State private var editingEntry: CaffeineEntry?
    @State private var editMg = ""
    @State private var editSource = ""
    @State private var showTimePicker = false
    @State private var customDate = Date.now
    @State private var historyRange: CaffeineEngine.HistoryRange = .week
    @State private var historyScaffoldTimeRange: DetailTimeRange = .week
    @State private var lastAddedEntry: CaffeineEntry?
    @State private var showUndo = false
    @State private var undoWorkItem: DispatchWorkItem?
    @FocusState private var isMgFocused: Bool

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var halfLife: Double { settings.caffeineHalfLife }
    private var dailyLimit: Double { Double(settings.dailyCaffeineLimit) }

    private var defaultMgForSource: Double {
        CaffeineEntry.presets.first { $0.name == selectedSource }?.mg ?? 0
    }

    private var effectiveMg: Double {
        if let custom = Double(customMg), custom > 0 { return custom }
        return defaultMgForSource
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let remaining = CaffeineEngine.totalMg(at: now, entries: entries, halfLifeHours: halfLife)
            let readiness = CaffeineTrackerSections.sleepReadinessPresentation(remaining)
            let tint = CaffeineTrackerSections.decayTint(colorScheme: colorScheme)

            ScrollView {
                LazyVStack(spacing: AppTheme.sectionSpacing) {
                    CaffeineTrackerSections.heroCard(
                        remaining: remaining,
                        readiness: readiness,
                        now: now,
                        entries: entries,
                        halfLife: halfLife,
                        dailyLimit: dailyLimit,
                        todayTotalMg: CaffeineEngine.todayLoggedMg(entries: entries)
                    )

                    let frequent = CaffeineEngine.frequentSources(entries: entries)
                    if !frequent.isEmpty {
                        CaffeineTrackerSections.quickLogCard(frequentSources: frequent, onQuickLog: quickLog)
                    }

                    CaffeineTrackerSections.dailyBudgetCard(
                        todayTotalMg: CaffeineEngine.todayLoggedMg(entries: entries),
                        dailyLimit: dailyLimit
                    )

                    if remaining > 0.5 {
                        CaffeineTrackerSections.decayCard(
                            from: now,
                            entries: entries,
                            halfLife: halfLife,
                            decayTint: tint
                        )
                    }

                    CaffeineTrackerSections.LogCaffeineCard(
                        selectedSource: $selectedSource,
                        customMg: $customMg,
                        showTimePicker: $showTimePicker,
                        customDate: $customDate,
                        isMgFocused: $isMgFocused,
                        defaultMgForSource: defaultMgForSource,
                        effectiveMg: effectiveMg,
                        onLog: logCaffeine
                    )

                    CaffeineTrackerSections.HistorySection(
                        historyRange: $historyRange,
                        scaffoldTimeRange: $historyScaffoldTimeRange,
                        entries: entries,
                        dailyLimit: dailyLimit
                    )

                    if entries.count >= 3 {
                        CaffeineTrackerSections.timeOfDayCard(
                            breakdown: CaffeineEngine.timeOfDayBreakdown(entries: entries)
                        )
                    }

                    let streak = CaffeineEngine.caffeineFreeStreak(entries: entries)
                    let lastFree = CaffeineEngine.daysSinceFreeDayText(entries: entries)
                    if streak > 0 || lastFree != nil {
                        CaffeineTrackerSections.streakCard(streak: streak, daysSinceFreeDayText: lastFree)
                    }

                    if !entries.isEmpty {
                        CaffeineTrackerSections.recentIntakeCard(
                            entries: entries,
                            halfLife: halfLife,
                            onEdit: { entry in
                                editMg = "\(Int(entry.milligrams))"
                                editSource = entry.source
                                editingEntry = entry
                            },
                            onDelete: { entryToDelete = $0 }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Caffeine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMgFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showUndo {
                UndoBar(icon: "cup.and.saucer.fill", message: "Caffeine logged", color: .brown, onUndo: undoLastEntry)
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
        } message: {
            Text("Remove this caffeine entry?")
        }
        .alert("Edit Entry", isPresented: Binding(
            get: { editingEntry != nil },
            set: { if !$0 { editingEntry = nil } }
        )) {
            TextField("mg", text: $editMg).keyboardType(.decimalPad)
            Button("Save") {
                if let entry = editingEntry, let mg = Double(editMg), mg > 0 {
                    entry.milligrams = mg
                    entry.source = editSource
                }
                editingEntry = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = editingEntry { modelContext.delete(entry) }
                editingEntry = nil
            }
            Button("Cancel", role: .cancel) { editingEntry = nil }
        } message: {
            if let entry = editingEntry { Text("Edit \(entry.source) — \(Int(entry.milligrams)) mg") }
        }
    }

    private func logCaffeine() {
        let date = showTimePicker ? customDate : .now
        let entry = CaffeineEntry(date: date, milligrams: effectiveMg, source: selectedSource)
        modelContext.insert(entry)
        customMg = ""
        showTimePicker = false
        customDate = .now
        isMgFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUndoSnackbar(for: entry)
        updateCaffeineWidget()
    }

    private func quickLog(source: String, mg: Double) {
        let entry = CaffeineEntry(milligrams: mg, source: source)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUndoSnackbar(for: entry)
        updateCaffeineWidget()
    }

    private func updateCaffeineWidget() {
        let cutoff = Date().addingTimeInterval(-12 * 3600)
        let recent = entries.filter { $0.date >= cutoff }.map { (date: $0.date, milligrams: $0.milligrams) }
        MetriclySyncCoordinator.publishCaffeine(
            entries: recent,
            halfLifeHours: settings.caffeineHalfLife,
            dailyLimitMg: Double(settings.dailyCaffeineLimit)
        )
    }

    private func showUndoSnackbar(for entry: CaffeineEntry) {
        lastAddedEntry = entry
        undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) { showUndo = true }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) { showUndo = false }
            lastAddedEntry = nil
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func undoLastEntry() {
        guard let entry = lastAddedEntry else { return }
        modelContext.delete(entry)
        lastAddedEntry = nil
        undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) { showUndo = false }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateCaffeineWidget()
    }
}

#Preview {
    NavigationStack { CaffeineTrackerView() }
        .modelContainer(for: [CaffeineEntry.self, UserSettings.self], inMemory: true)
}
