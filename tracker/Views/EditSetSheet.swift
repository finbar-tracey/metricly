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
    @State private var distance: Double
    @State private var durationMinutes: Int
    @State private var durationSeconds: Int
    @FocusState private var isWeightFieldFocused: Bool

    private var isCardio: Bool {
        exerciseSet.isCardio
    }

    init(exerciseSet: ExerciseSet, reps: Int, weight: Double, distanceUnit: DistanceUnit = .km) {
        self.exerciseSet = exerciseSet
        _reps = State(initialValue: reps)
        _weight = State(initialValue: weight)
        _rpe = State(initialValue: exerciseSet.rpe)
        _distance = State(initialValue: distanceUnit.display(exerciseSet.distance ?? 5.0))
        let totalSecs = exerciseSet.durationSeconds ?? 0
        _durationMinutes = State(initialValue: totalSecs / 60)
        _durationSeconds = State(initialValue: totalSecs % 60)
    }

    private var weightIncrement: Double {
        weightUnit == .kg ? 2.5 : 5.0
    }

    var body: some View {
        NavigationStack {
            Form {
                if isCardio {
                    cardioSections
                } else {
                    strengthSections
                }

                // RPE section (shared)
                if !exerciseSet.isWarmUp || isCardio {
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
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    rpe = value
                                } label: {
                                    Text("\(value)")
                                        .font(.system(size: 14, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background {
                                            if rpe == value {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [.purple, AppTheme.Signal.focus],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .shadow(color: .purple.opacity(0.40), radius: 6, y: 3)
                                            } else {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color(.tertiarySystemFill))
                                            }
                                        }
                                        .foregroundStyle(rpe == value ? .white : .primary)
                                }
                                .buttonStyle(.pressableCard)
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
                        if isCardio {
                            let totalSecs = durationMinutes * 60 + durationSeconds
                            exerciseSet.distance = weightUnit.distanceUnit.toKm(distance)
                            exerciseSet.durationSeconds = totalSecs > 0 ? totalSecs : nil
                        } else {
                            exerciseSet.reps = reps
                            exerciseSet.weight = weightUnit.toKg(weight)
                        }
                        exerciseSet.rpe = rpe
                        HapticsManager.success()
                        dismiss()
                    }
                    .font(.headline)
                }
            }
        }
    }

    // MARK: - Cardio Fields

    @ViewBuilder
    private var cardioSections: some View {
        Section {
            HStack {
                Label {
                    Text("Distance")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "point.bottomleft.forward.to.point.topright.scurvepath")
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    distance = max(0.1, distance - weightUnit.distanceUnit.stepSize)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }
                .buttonStyle(.pressableCard)
                Text(String(format: "%.1f %@", distance, weightUnit.distanceUnit.label))
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 100)
                    .contentTransition(.numericText())
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    distance += weightUnit.distanceUnit.stepSize
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.pressableCard)
            }
        }

        Section {
            HStack {
                Label {
                    Text("Duration")
                        .font(.subheadline)
                } icon: {
                    Image(systemName: "stopwatch")
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
                Picker("Min", selection: $durationMinutes) {
                    ForEach(0..<181) { m in
                        Text("\(m)m").tag(m)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
                Picker("Sec", selection: $durationSeconds) {
                    ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { s in
                        Text("\(s)s").tag(s)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()
            }
        }
    }

    // MARK: - Strength Fields

    @ViewBuilder
    private var strengthSections: some View {
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
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .contentTransition(.numericText())
            }
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    weight = max(0, weight - weightIncrement)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor.opacity(0.8))
                }
                .buttonStyle(.pressableCard)
                Spacer()
                TextField("Weight", value: $weight, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .frame(width: 100)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                    .background(Color(.tertiarySystemFill), in: .rect(cornerRadius: 10))
                    .focused($isWeightFieldFocused)
                    .onChange(of: weight) {
                        if weight < 0 { weight = 0 }
                    }
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    weight += weightIncrement
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.pressableCard)
            }
        }
    }
}
