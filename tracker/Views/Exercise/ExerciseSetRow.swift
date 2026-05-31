import SwiftUI
import SwiftData
import UIKit

// MARK: - Section chrome

struct ExerciseSetsSectionHeader: View {
    let workingCount: Int
    let lastSessionSummary: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "repeat")
                .font(.caption.bold())
                .foregroundStyle(Color.accentColor)
            Text("\(workingCount) Working")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Spacer()
            if let lastSessionSummary {
                HStack(spacing: 4) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 10))
                    Text(lastSessionSummary)
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.tertiary)
            }
        }
        .textCase(nil)
    }
}

struct ExerciseSetRowBackground: View {
    let exerciseSet: ExerciseSet
    let isPR: Bool

    var body: some View {
        let base = Color(.secondarySystemGroupedBackground)
        if exerciseSet.isWarmUp {
            ZStack { base; AppTheme.Signal.caution.opacity(0.07) }
        } else if isPR {
            ZStack { base; AppTheme.Signal.amber.opacity(0.08) }
        } else {
            base
        }
    }
}

// MARK: - Set row

struct ExerciseSetRow: View {
    let exercise: Exercise
    let index: Int
    let exerciseSet: ExerciseSet
    @Bindable var session: ExerciseSessionState
    let weightUnit: WeightUnit
    let isPR: (ExerciseSet) -> Bool
    let warmUpCountBefore: (Int) -> Int
    let onDuplicate: () -> Void

    private var weightIncrement: Double {
        weightUnit == .kg ? 2.5 : 5.0
    }

    var body: some View {
        let isEditing = session.inlineEditingSetID == exerciseSet.persistentModelID
        Group {
            if isEditing && !exerciseSet.isCardio {
                inlineEditRow
            } else {
                displayRow
            }
        }
        .swipeActions(edge: .leading) {
            Button(action: onDuplicate) {
                Label("Duplicate", systemImage: "doc.on.doc")
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button {
                exerciseSet.isWarmUp.toggle()
                HapticsManager.lightTap()
            } label: {
                Label(exerciseSet.isWarmUp ? "Working" : "Warm-up",
                      systemImage: exerciseSet.isWarmUp ? "flame.fill" : "flame")
            }
            .tint(.orange)
        }
    }

    private var displayRow: some View {
        let setNumber = index + 1 - warmUpCountBefore(index)
        let badgeColor: Color = exerciseSet.isWarmUp ? .orange : .accentColor
        let isPRSet = !exerciseSet.isWarmUp && isPR(exerciseSet)

        return HStack(spacing: 12) {
            indexBadge(badgeColor: badgeColor, setNumber: setNumber, isWarmUp: exerciseSet.isWarmUp)

            if exerciseSet.isCardio {
                cardioSetData
            } else {
                HStack(spacing: 0) {
                    Text("\(exerciseSet.reps)")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(exerciseSet.isWarmUp ? .secondary : .primary)
                        .frame(width: 40, alignment: .trailing)
                    Text("×")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .frame(width: 22, alignment: .center)
                    Text(weightUnit.format(exerciseSet.weight))
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(exerciseSet.isWarmUp ? .secondary : .primary)
                        .frame(minWidth: 80, alignment: .leading)
                }
            }

            Spacer(minLength: 6)

            if let rpe = exerciseSet.rpe {
                Text("RPE \(rpe)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.purple.opacity(0.14), in: .capsule)
            }
            if isPRSet {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.Signal.amber)
                    .accessibilityLabel("Personal record")
            }
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .onTapGesture {
            if exerciseSet.isCardio {
                session.editingSet = exerciseSet
                session.editReps = exerciseSet.reps
                session.editWeight = weightUnit.display(exerciseSet.weight)
            } else {
                withAnimation(.snappy(duration: 0.20)) {
                    session.inlineEditingSetID = exerciseSet.persistentModelID
                }
                HapticsManager.lightTap()
            }
        }
        .onLongPressGesture(minimumDuration: 0.4) {
            session.editingSet = exerciseSet
            session.editReps = exerciseSet.reps
            session.editWeight = weightUnit.display(exerciseSet.weight)
            HapticsManager.lightTap()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(setAccessibilityLabel)
        .accessibilityHint("Tap to edit reps and weight, long press for more")
    }

    private var inlineEditRow: some View {
        let setNumber = index + 1 - warmUpCountBefore(index)
        let badgeColor: Color = exerciseSet.isWarmUp ? .orange : .accentColor
        let displayWeight = weightUnit.display(exerciseSet.weight)

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                indexBadge(badgeColor: badgeColor, setNumber: setNumber, isWarmUp: exerciseSet.isWarmUp)

                HStack(spacing: 4) {
                    inlineStepButton(systemName: "minus.circle.fill") {
                        exerciseSet.reps = max(1, exerciseSet.reps - 1)
                    }
                    Text("\(exerciseSet.reps)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 22)
                    inlineStepButton(systemName: "plus.circle.fill") {
                        exerciseSet.reps += 1
                    }
                }

                Text("×").font(.caption2).foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    inlineStepButton(systemName: "minus.circle.fill") {
                        let newDisplay = max(0, displayWeight - weightIncrement)
                        exerciseSet.weight = weightUnit.toKg(newDisplay)
                    }
                    Text(weightUnit.format(exerciseSet.weight))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 64)
                    inlineStepButton(systemName: "plus.circle.fill") {
                        let newDisplay = displayWeight + weightIncrement
                        exerciseSet.weight = weightUnit.toKg(newDisplay)
                    }
                }

                Spacer(minLength: 4)

                Button {
                    withAnimation(.snappy(duration: 0.20)) {
                        session.inlineEditingSetID = nil
                    }
                    HapticsManager.lightTap()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Done editing")
            }

            if !exerciseSet.isWarmUp {
                inlineRPERow
            }
        }
        .padding(.vertical, 4)
    }

    private var inlineRPERow: some View {
        HStack(spacing: 6) {
            Text("RPE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    exerciseSet.rpe = (exerciseSet.rpe == value) ? nil : value
                } label: {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(exerciseSet.rpe == value ? .white : .purple)
                        .frame(width: 26, height: 26)
                        .background(
                            exerciseSet.rpe == value ? Color.purple : Color.purple.opacity(0.12),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            if exerciseSet.rpe != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    exerciseSet.rpe = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear RPE")
            }
        }
        .padding(.leading, 36)
    }

    private func indexBadge(badgeColor: Color, setNumber: Int, isWarmUp: Bool) -> some View {
        ZStack {
            Circle()
                .fill(badgeColor.opacity(0.18))
                .frame(width: 28, height: 28)
            if isWarmUp {
                Image(systemName: "flame.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
            } else {
                Text("\(setNumber)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(badgeColor)
            }
        }
    }

    private func inlineStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title2)
                .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 34, minHeight: 34)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var cardioSetData: some View {
        HStack(spacing: 6) {
            if let dist = exerciseSet.formattedDistance(unit: weightUnit.distanceUnit) {
                Text(dist)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            if let dur = exerciseSet.formattedDuration {
                Text(dur)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var setAccessibilityLabel: String {
        var parts: [String] = []
        if exerciseSet.isWarmUp {
            parts.append("Warm-up set")
        } else {
            parts.append("Set \(index + 1 - warmUpCountBefore(index))")
        }
        parts.append("\(exerciseSet.reps) reps at \(weightUnit.format(exerciseSet.weight))")
        if isPR(exerciseSet) {
            parts.append("Personal record")
        }
        return parts.joined(separator: ", ")
    }
}
