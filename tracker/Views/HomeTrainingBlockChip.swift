import SwiftUI
import SwiftData

/// Home-surface chip that names the user's active training block —
/// "Week 2 of 4 · Accumulation" with a subtle phase-coloured leading
/// glyph and trailing chevron.
///
/// **Two states.**
///   - **Active block.** Shows phase + week progress. Tap is a no-op
///     this sprint (a future TrainingBlockDetailView will swap in
///     here without a Home edit).
///   - **No active block.** Shows a "Start a 4-week accumulation
///     block" CTA. Tap inserts a `TrainingBlock` starting today
///     using the engine's recommendation — usually `.accumulate`
///     for 4 weeks, unless the user just finished a block, in which
///     case the next phase rolls forward.
///
/// **Why this lives in its own file.** HomeDashboardView is already
/// at its decomposition limit (one of the v1.4 review's tickets);
/// dropping more inline view-builders into the body section will
/// bring back the Swift type-checker stack issues that AnyView
/// erasure works around.
struct HomeTrainingBlockChip: View {

    /// The user's active block at `now`. Nil triggers the start-CTA
    /// state. Parent owns the @Query — passing the resolved value in
    /// keeps this view side-effect-free aside from the start tap.
    let activeBlock: TrainingBlock?
    /// The full block history — needed by the engine to recommend
    /// what kind of block to start on tap. Ordered however the parent
    /// query returned them; the engine doesn't require a particular sort.
    let allBlocks: [TrainingBlock]
    /// Insertion callback. Owns the `ModelContext.insert` + save so
    /// this view doesn't take a context dependency. Parent passes a
    /// closure capturing its own context.
    let onStartBlock: (TrainingBlock) -> Void
    /// Tap callback for the active-state chip — usually presents
    /// `TrainingBlockDetailView`. Defaults to a no-op so previews
    /// and tests don't need to wire it.
    var onTapActive: () -> Void = {}

    var body: some View {
        if let block = activeBlock {
            Button(action: onTapActive) {
                activeChip(for: block)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens block details")
        } else {
            startCTA
        }
    }

    // MARK: - Active

    private func activeChip(for block: TrainingBlock) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(palette(for: block.phase).opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: block.phase.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(palette(for: block.phase))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(progressLabel(for: block))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(block.phase.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.phase.label) block, \(progressLabel(for: block))")
    }

    // MARK: - Start CTA

    private var startCTA: some View {
        Button(action: handleStartTap) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(AppTheme.Signal.focus.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppTheme.Signal.focus)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a training block")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text(ctaSubtitle)
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
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint("Inserts a training block starting today")
    }

    /// Subtitle on the start CTA. Pulls from the engine's
    /// recommendation so the user sees what they're about to start
    /// (4-week accumulate by default, 1-week deload after an
    /// accumulate). The rationale string from the engine doubles as
    /// the explanatory copy.
    private var ctaSubtitle: String {
        let rec = TrainingBlockEngine.recommend(from: allBlocks)
        return rec.rationale
    }

    private func handleStartTap() {
        let rec = TrainingBlockEngine.recommend(from: allBlocks)
        let block = TrainingBlock(
            startDate: .now,
            weekCount: rec.nextWeekCount,
            phase: rec.nextPhase
        )
        onStartBlock(block)
    }

    // MARK: - Helpers

    private func progressLabel(for block: TrainingBlock) -> String {
        TrainingBlockEngine.progressLabel(for: block) ?? block.phase.label
    }

    /// Phase → accent color for the leading glyph. Recovery green for
    /// deload (it's an active recovery week), strain red for
    /// accumulate (it's the loading phase). The semantic mapping is
    /// intentional — deload reads as a *good* thing in the app, not
    /// a punishment.
    private func palette(for phase: TrainingBlock.Phase) -> Color {
        switch phase {
        case .accumulate: return AppTheme.Signal.strain
        case .deload:     return AppTheme.Signal.recovery
        }
    }
}

#Preview("Active accumulate") {
    HomeTrainingBlockChip(
        activeBlock: TrainingBlock(
            startDate: Calendar.current.date(byAdding: .day, value: -7, to: .now)!,
            weekCount: 4,
            phase: .accumulate
        ),
        allBlocks: [],
        onStartBlock: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("No block") {
    HomeTrainingBlockChip(
        activeBlock: nil,
        allBlocks: [],
        onStartBlock: { _ in }
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
