import SwiftUI
import WatchKit

// MARK: - WatchExerciseLogView

struct WatchExerciseLogView: View {
    @Binding var exercise: WatchExerciseRecord
    let sessionManager: WatchWorkoutSessionManager

    @EnvironmentObject private var connectivity: WatchConnectivityManager

    @State private var showingLogSet   = false
    @State private var showingRestTimer = false
    @State private var pendingReps   : Int    = 8
    @State private var pendingWeight : Double = 60
    @State private var isWarmUp      = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "heart.fill")
                    .font(.caption2.bold())
                    .foregroundStyle(.red)
                Text(sessionManager.heartRate > 0 ? "\(Int(sessionManager.heartRate)) bpm" : "--")
                    .font(.caption2)
                    .monospacedDigit()
                Spacer()
                Text(formatDuration(sessionManager.elapsedSeconds))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.ultraThinMaterial)

            List {
                ForEach(Array(exercise.sets.enumerated()), id: \.offset) { i, set in
                    HStack {
                        Text(set.isWarmUp ? "W" : "\(i + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(set.isWarmUp ? .orange : .secondary)
                            .frame(width: 18)
                        Text("\(set.reps) × \(formatWeight(set.weightKg, useKg: connectivity.useKg))")
                            .font(.subheadline)
                    }
                }
                .onDelete { idx in exercise.sets.remove(atOffsets: idx) }

                Button {
                    if let last = exercise.sets.last {
                        pendingReps   = last.reps
                        pendingWeight = last.weightKg
                    }
                    isWarmUp      = false
                    showingLogSet = true
                } label: {
                    Label("Log Set", systemImage: "plus.circle.fill")
                        .foregroundStyle(.green)
                }

                Button {
                    if let last = exercise.sets.last {
                        pendingReps   = last.reps
                        pendingWeight = last.weightKg
                    }
                    isWarmUp      = true
                    showingLogSet = true
                } label: {
                    Label("Warm-up", systemImage: "flame")
                        .foregroundStyle(.orange)
                        .font(.caption)
                }

            }
        }
        .navigationTitle(exercise.name)
        .sheet(isPresented: $showingLogSet) {
            WatchLogSetSheet(
                reps:     $pendingReps,
                weightKg: $pendingWeight,
                isWarmUp: isWarmUp,
                useKg:    connectivity.useKg
            ) {
                exercise.sets.append(
                    WatchSetRecord(reps: pendingReps, weightKg: pendingWeight, isWarmUp: isWarmUp)
                )
                if !isWarmUp { showingRestTimer = true }
            }
        }
        .sheet(isPresented: $showingRestTimer) {
            WatchRestTimerView(duration: connectivity.restDuration(for: exercise.name))
        }
    }
}

// MARK: - WatchLogSetSheet

struct WatchLogSetSheet: View {
    @Binding var reps:     Int
    @Binding var weightKg: Double
    let isWarmUp: Bool
    var useKg:    Bool = true
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var crownWeight: Double = 0
    @FocusState private var weightFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isWarmUp {
                    Text("Warm-up").font(.caption.bold()).foregroundStyle(.orange)
                }

                weightStepper

                Divider()

                HStack(spacing: 16) {
                    stepButton(systemName: "minus.circle.fill") {
                        reps = max(1, reps - 1)
                    }
                    VStack(spacing: 2) {
                        Text("\(reps)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("reps").font(.caption2).foregroundStyle(.secondary)
                    }
                    stepButton(systemName: "plus.circle.fill") {
                        reps += 1
                    }
                }

                Button {
                    WKInterfaceDevice.current().play(isWarmUp ? .click : .success)
                    onSave()
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isWarmUp ? .orange : .green)
            }
            .padding()
        }
        .navigationTitle("Log Set")
    }

    private var increment: Double { useKg ? 2.5 : 5.0 }

    private var weightStepper: some View {
        let displayWeight = useKg ? weightKg : weightKg * 2.20462

        return VStack(spacing: 4) {
            HStack(spacing: 14) {
                stepButton(systemName: "minus.circle.fill") {
                    let newDisplay = max(0, displayWeight - increment)
                    weightKg = useKg ? newDisplay : newDisplay / 2.20462
                    crownWeight = newDisplay
                }
                Text(String(format: displayWeight.truncatingRemainder(dividingBy: 1) == 0
                                       ? "%.0f" : "%.1f", displayWeight))
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .focusable()
                    .focused($weightFocused)
                    .digitalCrownRotation(
                        $crownWeight,
                        from: 0, through: useKg ? 500 : 1100, by: increment,
                        sensitivity: .low,
                        isContinuous: false
                    )
                    .onChange(of: crownWeight) { _, v in
                        weightKg = useKg ? max(0, v) : max(0, v / 2.20462)
                    }
                    .onAppear {
                        crownWeight = useKg ? weightKg : weightKg * 2.20462
                        weightFocused = true
                    }
                stepButton(systemName: "plus.circle.fill") {
                    let newDisplay = displayWeight + increment
                    weightKg = useKg ? newDisplay : newDisplay / 2.20462
                    crownWeight = newDisplay
                }
            }
            Text(useKg ? "kg" : "lb")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func stepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button {
            WKInterfaceDevice.current().play(.click)
            action()
        } label: {
            Image(systemName: systemName)
                .font(.title3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - AddExerciseSheet

struct AddExerciseSheet: View {
    let recentExercises: [String]
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""
    @State private var showingCustomEntry = false

    private let commonExercises: [String] = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press",
        "Barbell Row", "Pull-up", "Dumbbell Press", "Lat Pulldown",
        "Bicep Curl", "Tricep Pushdown", "Leg Press", "Lunges",
        "Hip Thrust", "Romanian Deadlift", "Lateral Raise", "Cable Row",
    ]

    private var dedupedRecents: [String] {
        let common = Set(commonExercises.map { $0.lowercased() })
        return recentExercises.filter { !common.contains($0.lowercased()) }
    }

    var body: some View {
        List {
            if !dedupedRecents.isEmpty {
                Section("Recent") {
                    ForEach(dedupedRecents.prefix(8), id: \.self) { name in
                        Button(name) { add(name) }
                    }
                }
            }

            Section("Common") {
                ForEach(commonExercises, id: \.self) { name in
                    Button(name) { add(name) }
                }
            }

            Section {
                Button {
                    showingCustomEntry = true
                } label: {
                    Label("Custom", systemImage: "keyboard")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Exercise")
        .sheet(isPresented: $showingCustomEntry) {
            CustomExerciseEntrySheet(text: $customName) {
                guard !customName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                add(customName.trimmingCharacters(in: .whitespaces))
            }
        }
    }

    private func add(_ name: String) {
        WKInterfaceDevice.current().play(.click)
        onAdd(name)
        dismiss()
    }
}

private struct CustomExerciseEntrySheet: View {
    @Binding var text: String
    let onSubmit: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            Text("Custom Exercise")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            TextField("Name", text: $text)
                .textFieldStyle(.plain)
                .font(.headline)
                .multilineTextAlignment(.center)
                .submitLabel(.done)
                .onSubmit {
                    onSubmit()
                    dismiss()
                }

            Button {
                onSubmit()
                dismiss()
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }
}

// MARK: - WatchFinishWorkoutView

struct WatchFinishWorkoutView: View {
    let workoutName: String
    let exercises:   [WatchExerciseRecord]
    let onFinish:    () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager

    private var totalSets: Int {
        exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)

            Text(workoutName)
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 16) {
                statCol("\(totalSets)", label: "Sets")
                statCol("\(Int(sessionManager.activeCalories))", label: "Cal")
                statCol(formatDuration(sessionManager.elapsedSeconds), label: "Time")
            }

            if sessionManager.maxHeartRate > 0 {
                Label("\(Int(sessionManager.maxHeartRate)) bpm peak", systemImage: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button("Finish") {
                onFinish()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding()
        .navigationTitle("Summary")
    }

    private func statCol(_ value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
    }
}
