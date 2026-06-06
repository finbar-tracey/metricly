import SwiftUI
import SwiftData

/// Today's plan adjustment banner and substitution suggestions.
struct WorkoutDetailPlanSection: View {
    let workout: Workout
    let planAdjustments: TodayPlan?
    let planAdjustmentsDismissed: Bool
    let trainingBlocks: [TrainingBlock]
    let dismissedSubstitutions: Set<PersistentIdentifier>
    let onDismissPlan: () -> Void
    let onApplyPlan: (TodayPlan) -> Void
    let onSwapSubstitution: (TodayPlanApply.SubstitutionSuggestion) -> Void
    let onKeepSubstitution: (PersistentIdentifier) -> Void

    var body: some View {
        if !workout.isTemplate {
            if let plan = planAdjustments,
               !plan.adjustments.isEmpty,
               !planAdjustmentsDismissed,
               !workout.isFinished {
                let preview = TodayPlanApply.preview(
                    plan: plan,
                    on: workout,
                    currentBlock: TrainingBlockEngine.currentBlock(in: trainingBlocks)
                )
                Section {
                    TodayPlanAdjustmentsBanner(
                        plan: plan,
                        onDismiss: onDismissPlan,
                        applyPreview: preview,
                        onApply: { onApplyPlan(plan) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init(top: 0, leading: 16, bottom: 8, trailing: 16))
                }
            }

            if let plan = planAdjustments,
               !planAdjustmentsDismissed,
               !workout.isFinished {
                let suggestions = TodayPlanApply.substitutionsFor(plan: plan, on: workout)
                    .filter { !dismissedSubstitutions.contains($0.exercise.persistentModelID) }
                if !suggestions.isEmpty {
                    Section {
                        substitutionsCard(suggestions)
                            .listRowBackground(Color.clear)
                            .listRowInsets(.init(top: 0, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
        }
    }

    private func substitutionsCard(_ suggestions: [TodayPlanApply.SubstitutionSuggestion]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.Signal.caution)
                Text(String(
                    localized: "Suggested swaps",
                    comment: "Section header above the substitution suggestions"
                ))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            }
            VStack(spacing: 10) {
                ForEach(suggestions, id: \.exercise.persistentModelID) { suggestion in
                    substitutionRow(suggestion)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
    }

    private func substitutionRow(_ suggestion: TodayPlanApply.SubstitutionSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .strikethrough()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right")
                            .font(.caption2.bold())
                            .foregroundStyle(.tertiary)
                        Text(suggestion.suggestedName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 8) {
                Button {
                    HapticsManager.success()
                    onSwapSubstitution(suggestion)
                } label: {
                    Text(String(localized: "Swap", comment: "Action accepting the substitution suggestion"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(AppTheme.Signal.caution)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous))
                }
                .buttonStyle(.plain)
                Button {
                    onKeepSubstitution(suggestion.exercise.persistentModelID)
                } label: {
                    Text(String(localized: "Keep", comment: "Action dismissing a single substitution suggestion"))
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
