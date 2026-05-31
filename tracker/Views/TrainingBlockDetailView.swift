import SwiftUI
import SwiftData

struct TrainingBlockDetailView: View {

    let block: TrainingBlock
    let allBlocks: [TrainingBlock]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var notesDraft: String = ""
    @State private var showEndEarlyConfirm = false
    @State private var showStartNextConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    TrainingBlockDetailSections.headerCard(
                        block: block,
                        palette: palette,
                        progressLabel: progressLabel,
                        dateRangeLabel: dateRangeLabel,
                        isActive: isActive,
                        daysRemaining: daysRemaining
                    )
                    TrainingBlockDetailSections.notesCard(notesDraft: $notesDraft)
                    TrainingBlockDetailSections.actionsCard(
                        isActive: isActive,
                        palette: palette,
                        nextPhaseLabel: nextPhase.label,
                        nextRationale: nextRecommendation.rationale,
                        onEndEarly: { showEndEarlyConfirm = true },
                        onStartNext: { showStartNextConfirm = true }
                    )
                    if !pastBlocks.isEmpty {
                        TrainingBlockDetailSections.historyCard(
                            pastBlocks: pastBlocks,
                            paletteForPhase: palette(for:),
                            formatRange: formatRange
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 24)
            }
            .navigationTitle("Training Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
        .onAppear { notesDraft = block.notes }
        .onChange(of: notesDraft) { _, newValue in
            block.notes = newValue
        }
        .confirmationDialog(
            "End this block today?",
            isPresented: $showEndEarlyConfirm,
            titleVisibility: .visible
        ) {
            Button("End block", role: .destructive, action: handleEndEarly)
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("The current block will end at the end of today. You can start the next one whenever you're ready.")
        }
        .confirmationDialog(
            startNextDialogTitle,
            isPresented: $showStartNextConfirm,
            titleVisibility: .visible
        ) {
            Button("Start \(nextPhase.label)", action: handleStartNext)
            Button("Not yet", role: .cancel) {}
        } message: {
            Text(startNextDialogMessage)
        }
    }

    private func handleEndEarly() {
        TrainingBlockApply.endEarly(block)
        try? modelContext.save()
    }

    private func handleStartNext() {
        TrainingBlockApply.startNext(from: allBlocks, in: modelContext)
        try? modelContext.save()
        dismiss()
    }

    private var palette: Color { palette(for: block.phase) }

    private func palette(for phase: TrainingBlock.Phase) -> Color {
        switch phase {
        case .accumulate: return AppTheme.Signal.strain
        case .deload:     return AppTheme.Signal.recovery
        }
    }

    private var isActive: Bool { block.contains(.now) }

    private var progressLabel: String {
        if isActive {
            return TrainingBlockEngine.progressLabel(for: block) ?? block.phase.label
        }
        return "Completed · \(block.weekCount)-week \(block.phase.label.lowercased())"
    }

    private var daysRemaining: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let days = cal.dateComponents([.day], from: today, to: block.endDate).day ?? 0
        return max(0, days)
    }

    private var dateRangeLabel: String {
        formatRange(start: block.startDate, end: block.endDate)
    }

    private func formatRange(start: Date, end: Date) -> String {
        let lastDay = Calendar.current.date(byAdding: .day, value: -1, to: end) ?? end
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return "\(f.string(from: start)) → \(f.string(from: lastDay))"
    }

    private var pastBlocks: [TrainingBlock] {
        allBlocks
            .filter { $0.id != block.id && $0.endDate <= block.startDate }
            .sorted { $0.startDate > $1.startDate }
    }

    private var nextRecommendation: TrainingBlockEngine.AdvancementRecommendation {
        TrainingBlockEngine.recommend(from: allBlocks)
    }

    private var nextPhase: TrainingBlock.Phase { nextRecommendation.nextPhase }

    private var startNextDialogTitle: String {
        "Start \(nextRecommendation.nextWeekCount)-week \(nextPhase.label.lowercased())?"
    }

    private var startNextDialogMessage: String { nextRecommendation.rationale }
}
