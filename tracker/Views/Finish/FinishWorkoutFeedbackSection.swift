import SwiftUI
import UIKit

enum FinishWorkoutFeedbackSection {
    static func trainedGroupsForSoreness(workout: Workout) -> [MuscleGroup] {
        let groups = workout.exercises.compactMap { exercise -> MuscleGroup? in
            guard let cat = exercise.category, cat != .cardio, cat != .other else { return nil }
            let hasWorkingSet = exercise.sets.contains { !$0.isWarmUp }
            return hasWorkingSet ? cat : nil
        }
        return Array(Set(groups)).sorted { $0.rawValue < $1.rawValue }
    }

    static func sorenessCard(
        trainedGroups: [MuscleGroup],
        sorenessLevels: Binding<[MuscleGroup: Int]>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "How sore are you?", comment: "Section header above the per-muscle soreness picker"),
                icon: "figure.cooldown", color: .purple
            )
            .accessibilityAddTraits(.isHeader)
            Text(String(
                localized: "Optional — tells the recovery engine where you actually feel it.",
                comment: "Caption under the soreness section explaining it's optional"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                ForEach(trainedGroups, id: \.self) { group in
                    HStack(spacing: 10) {
                        Text(group.rawValue).font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, alignment: .leading)
                        sorenessPicker(for: group, sorenessLevels: sorenessLevels)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .appCard()
    }

    static func feelCard(feel: Binding<WorkoutFeedbackEvent.Feel?>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "How did it feel?", comment: "Section header above the post-workout feel picker"),
                icon: "thermometer.medium",
                color: .pink
            )
            .accessibilityAddTraits(.isHeader)
            Text(String(
                localized: "Optional — helps Metricly tune your next plan to match what you felt.",
                comment: "Caption under the post-workout feel picker explaining it's optional"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(WorkoutFeedbackEvent.Feel.allCases) { option in
                    feelButton(option, feel: feel)
                }
            }
        }
    }

    static func notesCard(notes: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Notes", comment: "Section header above the workout notes text field"),
                icon: "note.text", color: .secondary
            )
            TextField(
                String(localized: "How did it feel? Any notes...", comment: "Placeholder text inside the workout notes field"),
                text: notes,
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(.subheadline)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    private static func sorenessPicker(for group: MuscleGroup, sorenessLevels: Binding<[MuscleGroup: Int]>) -> some View {
        let level = sorenessLevels.wrappedValue[group] ?? 0
        return HStack(spacing: 4) {
            ForEach(0...4, id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    sorenessLevels.wrappedValue[group] = value
                } label: {
                    let isSelected = value == level
                    Circle()
                        .fill(isSelected ? SorenessEntry.Level.tint(forLevel: value) : Color(.tertiarySystemGroupedBackground))
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle().stroke(isSelected ? SorenessEntry.Level.tint(forLevel: value) : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                        .overlay(
                            Text("\(value)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(isSelected ? .white : .secondary)
                        )
                        .accessibilityLabel("\(SorenessEntry.Level(rawValue: value)?.label ?? "level \(value)") soreness for \(group.rawValue)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                .buttonStyle(.plain)
            }
        }
    }

    private static func feelButton(_ option: WorkoutFeedbackEvent.Feel, feel: Binding<WorkoutFeedbackEvent.Feel?>) -> some View {
        let isSelected = feel.wrappedValue == option
        let tint: Color = switch option {
        case .tooEasy: AppTheme.Signal.calm
        case .aboutRight: AppTheme.Signal.recovery
        case .tooHard: AppTheme.Signal.strain
        }
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                feel.wrappedValue = isSelected ? nil : option
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: option.icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : tint)
                Text(option.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? tint : Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? tint : Color.secondary.opacity(0.18), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
