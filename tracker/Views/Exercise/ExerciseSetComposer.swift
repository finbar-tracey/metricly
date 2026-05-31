import SwiftUI
import UIKit

struct ExerciseNewSetSection: View {
    let exercise: Exercise
    @Bindable var session: ExerciseSessionState
    let weightUnit: WeightUnit
    let isCardioExercise: Bool
    let suggestedSet: SuggestedSet?
    var isWeightFieldFocused: FocusState<Bool>.Binding
    let onAddSet: () -> Void

    private var weightIncrement: Double {
        weightUnit == .kg ? 2.5 : 5.0
    }

    var body: some View {
        Section {
            if !isCardioExercise, let s = suggestedSet {
                SuggestedSetPill(suggestion: s) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.newReps = s.reps
                    session.newWeight = weightUnit.display(s.weight)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 6, trailing: 16))
            }

            if isCardioExercise {
                cardioInputFields
                rpePicker
                addEntryButton
            } else {
                nextSetRow
                if !session.newIsWarmUp {
                    rpePicker
                }
            }
        } header: {
            SectionHeader(
                title: session.newIsWarmUp ? "New Warm-up" : "New Set",
                icon: "plus.circle.fill",
                color: session.newIsWarmUp ? .orange : .accentColor
            )
        }
    }

    private var nextSetRow: some View {
        let badgeColor: Color = session.newIsWarmUp ? .orange : .accentColor
        let nextNumber = exercise.sets.filter { !$0.isWarmUp }.count + 1
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .strokeBorder(badgeColor.opacity(0.45),
                                      style: StrokeStyle(lineWidth: 1.5, dash: [3, 2]))
                        .background(Circle().fill(badgeColor.opacity(0.10)))
                        .frame(width: 28, height: 28)
                    if session.newIsWarmUp {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(nextNumber)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(badgeColor)
                    }
                }

                HStack(spacing: 4) {
                    stepButton(systemName: "minus.circle.fill") {
                        session.newReps = max(1, session.newReps - 1)
                    }
                    Text("\(session.newReps)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 24)
                    stepButton(systemName: "plus.circle.fill") {
                        session.newReps = min(100, session.newReps + 1)
                    }
                }

                Text("×").font(.caption2).foregroundStyle(.tertiary)

                HStack(spacing: 4) {
                    stepButton(systemName: "minus.circle.fill") {
                        session.newWeight = max(0, session.newWeight - weightIncrement)
                    }
                    Text(weightUnit.format(session.newWeight))
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .frame(minWidth: 64)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isWeightFieldFocused.wrappedValue = true
                        }
                        .accessibilityLabel("Weight: \(weightUnit.format(session.newWeight))")
                        .overlay {
                            TextField("", value: $session.newWeight, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .focused(isWeightFieldFocused)
                                .opacity(isWeightFieldFocused.wrappedValue ? 1 : 0)
                                .frame(width: 64)
                                .onChange(of: session.newWeight) {
                                    if session.newWeight < 0 { session.newWeight = 0 }
                                }
                        }
                    stepButton(systemName: "plus.circle.fill") {
                        session.newWeight += weightIncrement
                    }
                }

                Spacer(minLength: 4)

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onAddSet()
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(session.newIsWarmUp ? Color.orange : Color.green)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(session.newIsWarmUp ? "Add warm-up" : "Add set")
            }

            HStack(spacing: 6) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.newIsWarmUp.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: session.newIsWarmUp ? "flame.fill" : "flame")
                            .font(.caption2.bold())
                        Text(session.newIsWarmUp ? "Warm-up" : "Mark as warm-up")
                            .font(.caption2)
                    }
                    .foregroundStyle(session.newIsWarmUp ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (session.newIsWarmUp ? Color.orange : Color.secondary)
                            .opacity(session.newIsWarmUp ? 0.16 : 0.08),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var addEntryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onAddSet()
        } label: {
            Label("Add Entry", systemImage: "plus.circle.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Color.accentColor, in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.pressableCard)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var cardioInputFields: some View {
        HStack {
            Label {
                Text("Distance")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            } icon: {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16)).frame(width: 28, height: 28)
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                session.newDistance = max(0.1, session.newDistance - weightUnit.distanceUnit.stepSize)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor.opacity(0.8))
            }
            .buttonStyle(.pressableCard)
            Text(String(format: "%.1f %@", session.newDistance, weightUnit.distanceUnit.label))
                .font(.system(size: 17, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.accentColor)
                .frame(minWidth: 90)
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                session.newDistance += weightUnit.distanceUnit.stepSize
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.pressableCard)
        }

        HStack {
            Label {
                Text("Duration")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            } icon: {
                ZStack {
                    Circle().fill(Color.accentColor.opacity(0.16)).frame(width: 28, height: 28)
                    Image(systemName: "stopwatch")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            Picker("Min", selection: $session.newDurationMinutes) {
                ForEach(0..<181) { m in
                    Text("\(m)m").tag(m)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            Picker("Sec", selection: $session.newDurationSeconds) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { s in
                    Text("\(s)s").tag(s)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
        }
    }

    private var rpePicker: some View {
        HStack(spacing: 6) {
            Text("RPE")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            ForEach([6, 7, 8, 9, 10], id: \.self) { value in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.newRPE = (session.newRPE == value) ? nil : value
                } label: {
                    Text("\(value)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(session.newRPE == value ? .white : .purple)
                        .frame(width: 26, height: 26)
                        .background(
                            session.newRPE == value ? Color.purple : Color.purple.opacity(0.12),
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            if session.newRPE != nil {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    session.newRPE = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear RPE")
            }
        }
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
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
}
