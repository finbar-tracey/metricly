import SwiftUI
import SwiftData

/// Sheet view that shows the full picture of a training block — the
/// "expand" target for the Home `HomeTrainingBlockChip` tap. Three
/// jobs:
///
///   1. **Story.** Phase + week progress + date range, so the user
///      sees the block's whole arc, not just today's slice.
///   2. **Notes.** Free-text capture ("first 4-week push after
///      holidays") that round-trips to the model — nothing
///      consumes notes algorithmically, but a year of these makes
///      a useful training journal.
///   3. **Actions.** "End block early" (truncates `weekCount` to
///      finish today) and "Start next block" (engine-driven
///      recommendation for what comes after). Plus a small past-
///      blocks list so the user can see their periodisation
///      history at a glance.
///
/// Sheet-only; not pushed onto a NavigationStack. Toolbar Done
/// button dismisses.
struct TrainingBlockDetailView: View {

    let block: TrainingBlock
    /// Past blocks, ordered newest-first by start date. Used to
    /// render the history list and to feed the engine's
    /// recommendation for what to start next.
    let allBlocks: [TrainingBlock]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Local mirror of `block.notes` so the TextField can bind to a
    /// stable @State value rather than to a SwiftData property
    /// (binding directly fights with the SwiftUI update cycle).
    /// Committed on Done / on every edit via the .onChange handler
    /// at the bottom.
    @State private var notesDraft: String = ""
    @State private var showEndEarlyConfirm = false
    @State private var showStartNextConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    notesCard
                    actionsCard
                    if pastBlocks.isEmpty == false {
                        historyCard
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
            // Commit on every keystroke; SwiftData batches the
            // underlying changes and the sheet dismisses with the
            // notes already persisted. No save() needed — the
            // ModelContext auto-saves on the next idle.
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

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(palette.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: block.phase.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(palette)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.phase.label)
                        .font(.title3.weight(.bold))
                    Text(block.phase.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progressLabel)
                        .font(.headline.weight(.bold))
                    Text(dateRangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(daysRemaining)")
                            .font(.title2.weight(.black).monospacedDigit())
                            .foregroundStyle(palette)
                        Text(daysRemaining == 1 ? "day left" : "days left")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Notes

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(.subheadline.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            TextField(
                "Why this block? Any focus or context.",
                text: $notesDraft,
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(.body)
        }
        .appCard()
    }

    // MARK: - Actions

    private var actionsCard: some View {
        VStack(spacing: 10) {
            if isActive {
                Button(role: .destructive) {
                    showEndEarlyConfirm = true
                } label: {
                    actionRow(
                        icon: "calendar.badge.minus",
                        title: "End block early",
                        subtitle: "Finish at the end of today"
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showStartNextConfirm = true
                } label: {
                    actionRow(
                        icon: "calendar.badge.plus",
                        title: "Start \(nextPhase.label.lowercased())",
                        subtitle: nextRecommendation.rationale
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .appCard()
    }

    private func actionRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Past blocks")
                    .font(.subheadline.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            VStack(spacing: 8) {
                ForEach(pastBlocks.prefix(6), id: \.id) { past in
                    historyRow(past)
                }
            }
        }
        .appCard()
    }

    private func historyRow(_ past: TrainingBlock) -> some View {
        HStack(spacing: 12) {
            Image(systemName: past.phase.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette(for: past.phase))
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(past.phase.label) · \(past.weekCount)w")
                    .font(.subheadline.weight(.semibold))
                Text(formatRange(start: past.startDate, end: past.endDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Action handlers

    private func handleEndEarly() {
        TrainingBlockApply.endEarly(block)
        try? modelContext.save()
        // Don't dismiss — the user can immediately see the "Start
        // next" CTA appear in the actions card (isActive flips to
        // false the next render pass).
    }

    private func handleStartNext() {
        TrainingBlockApply.startNext(
            from: allBlocks,
            in: modelContext
        )
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Derived

    private var palette: Color { palette(for: block.phase) }

    private func palette(for phase: TrainingBlock.Phase) -> Color {
        switch phase {
        case .accumulate: return AppTheme.Signal.strain
        case .deload:     return AppTheme.Signal.recovery
        }
    }

    private var isActive: Bool {
        block.contains(.now)
    }

    private var progressLabel: String {
        if isActive {
            return TrainingBlockEngine.progressLabel(for: block) ?? block.phase.label
        } else {
            return "Completed · \(block.weekCount)-week \(block.phase.label.lowercased())"
        }
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
        // Subtract a day from endDate for display — endDate is the
        // *exclusive* upper bound (the day after the last day of the
        // block); users think in inclusive ranges.
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

    // MARK: - Next-block dialog

    private var nextRecommendation: TrainingBlockEngine.AdvancementRecommendation {
        TrainingBlockEngine.recommend(from: allBlocks)
    }

    private var nextPhase: TrainingBlock.Phase {
        nextRecommendation.nextPhase
    }

    private var startNextDialogTitle: String {
        "Start \(nextRecommendation.nextWeekCount)-week \(nextPhase.label.lowercased())?"
    }

    private var startNextDialogMessage: String {
        nextRecommendation.rationale
    }
}
