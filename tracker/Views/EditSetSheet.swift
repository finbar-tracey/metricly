import SwiftUI
import SwiftData

struct EditSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.weightUnit) private var weightUnit
    @Query private var settingsArray: [UserSettings]
    let exerciseSet: ExerciseSet
    @State private var reps: Int
    @State private var weight: Double
    @State private var rpe: Int?
    @FocusState private var isWeightFieldFocused: Bool

    init(exerciseSet: ExerciseSet, reps: Int, weight: Double) {
        self.exerciseSet = exerciseSet
        _reps = State(initialValue: reps)
        _weight = State(initialValue: weight)
        _rpe = State(initialValue: exerciseSet.rpe)
    }

    private var weightIncrement: Double {
        weightUnit == .kg ? 2.5 : 5.0
    }

    var body: some View {
        NavigationStack {
            Form {
                // Reps section
                Section {
                    HStack {
                        Label {
                            Text("Reps")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "repeat")
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                        Text("\(reps)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .frame(minWidth: 50)
                            .contentTransition(.numericText())
                    }
                    Stepper("Reps", value: $reps, in: 1...100)
                        .labelsHidden()
                }

                // Weight section
                Section {
                    HStack {
                        Label {
                            Text("Weight")
                                .font(.subheadline)
                        } icon: {
                            Image(systemName: "scalemass.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                        Spacer()
                        Text(weightUnit.format(weight))
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    HStack {
                        Button {
                            weight = max(0, weight - weightIncrement)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        TextField("Weight", value: $weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.center)
                            .font(.body.monospacedDigit())
                            .frame(width: 100)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 8))
                            .focused($isWeightFieldFocused)
                            .onChange(of: weight) {
                                if weight < 0 { weight = 0 }
                            }
                        Spacer()
                        Button {
                            weight += weightIncrement
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // RPE section
                if !exerciseSet.isWarmUp {
                    Section {
                        HStack {
                            Label {
                                Text("RPE")
                                    .font(.subheadline)
                            } icon: {
                                Image(systemName: "gauge.with.needle")
                                    .foregroundStyle(.purple)
                            }
                            Spacer()
                            if rpe != nil {
                                Button("Clear") {
                                    rpe = nil
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach(1...10, id: \.self) { value in
                                Button {
                                    rpe = value
                                } label: {
                                    Text("\(value)")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .background(rpe == value ? Color.accentColor : Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))
                                        .foregroundStyle(rpe == value ? .white : .primary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } footer: {
                        Text("Rate of Perceived Exertion (optional)")
                    }
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isWeightFieldFocused = false
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        exerciseSet.reps = reps
                        exerciseSet.weight = weightUnit.toKg(weight)
                        exerciseSet.rpe = rpe
                        HapticsManager.success()
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }
}
