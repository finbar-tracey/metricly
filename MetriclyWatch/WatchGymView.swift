import SwiftUI
import HealthKit
import WatchKit

// MARK: - WatchGymView
// Main gym workout screen. Shows:
// - Pre-workout: start button + today's plan / recent exercises
// - Active workout: exercise list with set logging + live HR bar

struct WatchGymView: View {
    @EnvironmentObject private var sessionManager: WatchWorkoutSessionManager
    @EnvironmentObject private var connectivity:   WatchConnectivityManager

    @State private var workoutName  = "Workout"
    @State private var exercises: [WatchExerciseRecord] = []
    @State private var showingNameEntry = false
    @State private var showingAddExercise = false
    @State private var showingFinish = false
    @State private var startDate: Date?

    var body: some View {
        if sessionManager.isRunning {
            activeView
        } else {
            preWorkoutView
        }
    }

    // MARK: - Pre-workout

    private var preWorkoutView: some View {
        ScrollView {
            VStack(spacing: 10) {
                // Today's plan card — shows the name + exercise preview if
                // the iPhone has pushed a planned workout for today.
                if !connectivity.todayPlanName.isEmpty {
                    todaysPlanCard
                }

                Button {
                    startWorkout()
                } label: {
                    Label(connectivity.todayPlannedExercises.isEmpty
                          ? "Start Gym"
                          : "Start \(connectivity.todayPlanName)",
                          systemImage: "dumbbell.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            }
            .padding()
        }
        .navigationTitle("Gym")
    }

    /// Shows the planned workout name + a short preview of the exercises that
    /// will be pre-populated. Helps users confirm the iPhone data made it
    /// across before they hit Start.
    private var todaysPlanCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.caption2)
                    .foregroundStyle(.blue)
                Text("Today")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text(connectivity.todayPlanName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if !connectivity.todayPlannedExercises.isEmpty {
                Text(connectivity.todayPlannedExercises.prefix(4).joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if connectivity.todayPlannedExercises.count > 4 {
                    Text("+\(connectivity.todayPlannedExercises.count - 4) more")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.blue.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Active workout

    private var activeView: some View {
        VStack(spacing: 0) {
            // Live HR banner
            hrBanner

            // Exercise list
            List {
                ForEach($exercises) { $exercise in
                    NavigationLink {
                        WatchExerciseLogView(exercise: $exercise, sessionManager: sessionManager)
                    } label: {
                        exerciseRow(exercise)
                    }
                }

                Button {
                    showingAddExercise = true
                } label: {
                    Label("Add Exercise", systemImage: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
        .navigationTitle(workoutName)
        // Finish lives in the top-right toolbar — much more discoverable than
        // being buried at the bottom of a long exercise list.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingFinish = true
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                .accessibilityLabel("Finish workout")
            }
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseSheet(
                recentExercises: connectivity.recentExercises
            ) { name in
                exercises.append(WatchExerciseRecord(name: name))
            }
        }
        .sheet(isPresented: $showingFinish) {
            WatchFinishWorkoutView(
                workoutName: workoutName,
                exercises: exercises
            ) {
                finishWorkout()
            }
        }
    }

    private var hrBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.fill")
                .font(.caption.bold())
                .foregroundStyle(hrColor)
                // Subtle pulse — visual confirmation HR is being read live.
                .symbolEffect(.pulse.byLayer, options: .repeating, isActive: sessionManager.heartRate > 0)
            Text(sessionManager.heartRate > 0 ? "\(Int(sessionManager.heartRate))" : "--")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
            // Zone pill — colour-coded so user sees what zone they're in
            // without having to interpret the number.
            if sessionManager.heartRate > 0 {
                Text(sessionManager.heartRateZone.rawValue)
                    .font(.system(size: 9, weight: .bold))
                    .textCase(.uppercase)
                    .foregroundStyle(hrColor)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(hrColor.opacity(0.18), in: Capsule())
            }
            Spacer()
            Text(formatDuration(sessionManager.elapsedSeconds))
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
    }

    private func exerciseRow(_ exercise: WatchExerciseRecord) -> some View {
        let workingSets = exercise.sets.filter { !$0.isWarmUp }
        let last = workingSets.last
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(rowSubtitle(workingSets: workingSets, last: last))
                    .font(.caption2)
                    .foregroundStyle(workingSets.isEmpty ? .tertiary : .secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            // Set count chip — at-a-glance progress on the right
            if !workingSets.isEmpty {
                Text("\(workingSets.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.green)
                    .frame(minWidth: 20)
            }
        }
    }

    private func rowSubtitle(workingSets: [WatchSetRecord], last: WatchSetRecord?) -> String {
        guard let last else { return "Tap to log" }
        return "Last: \(last.reps) × \(formatWeight(last.weightKg, useKg: connectivity.useKg))"
    }

    // MARK: - Actions

    private func startWorkout() {
        startDate   = .now
        workoutName = connectivity.todayPlanName.isEmpty
            ? "Workout" : connectivity.todayPlanName

        // Pre-populate the exercise list from today's planned workout (if the
        // iPhone has sent one). Otherwise start empty — the user can still
        // add exercises one at a time.
        exercises = connectivity.todayPlannedExercises.map {
            WatchExerciseRecord(name: $0)
        }

        Task {
            await sessionManager.requestAuthorization()
            try? await sessionManager.startSession(
                activityType: .traditionalStrengthTraining,
                isIndoor: true
            )
        }
    }

    private func finishWorkout() {
        let end = Date.now
        let payload = WatchWorkoutPayload(
            id:           UUID(),
            name:         workoutName,
            startDate:    startDate ?? end,
            endDate:      end,
            totalCalories: sessionManager.activeCalories > 0 ? sessionManager.activeCalories : nil,
            avgHeartRate: sessionManager.heartRate > 0 ? sessionManager.heartRate : nil,
            maxHeartRate: sessionManager.maxHeartRate > 0 ? sessionManager.maxHeartRate : nil,
            exercises:    exercises.map { ex in
                WatchExercisePayload(
                    name: ex.name,
                    sets: ex.sets.map { s in
                        WatchSetPayload(reps: s.reps, weightKg: s.weightKg, isWarmUp: s.isWarmUp)
                    }
                )
            }
        )

        Task {
            try? await sessionManager.endSession()
            WatchConnectivityManager.shared.sendWorkout(payload)
        }

        exercises   = []
        startDate   = nil
        showingFinish = false
    }

    private var hrColor: Color {
        switch sessionManager.heartRateZone {
        case .resting: return .gray
        case .fat:     return .blue
        case .cardio:  return .green
        case .peak:    return .orange
        case .max:     return .red
        }
    }
}

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
            // Live HR strip
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

            // Set list
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
                    // Pre-fill from last set
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
                // Auto-start rest timer for working sets
                if !isWarmUp { showingRestTimer = true }
            }
        }
        .sheet(isPresented: $showingRestTimer) {
            WatchRestTimerView(duration: connectivity.restDuration)
        }
    }
}

// MARK: - WatchLogSetSheet
// Crown scrolls weight; +/- buttons for reps.

struct WatchLogSetSheet: View {
    @Binding var reps:     Int
    @Binding var weightKg: Double
    let isWarmUp: Bool
    var useKg:    Bool = true
    let onSave: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var crownWeight: Double = 0
    /// Modern @FocusState replaces the deprecated `focusable(true, onFocusChange:)`
    /// API which was unstable and a likely crash source on watchOS 26.
    @FocusState private var weightFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if isWarmUp {
                    Text("Warm-up").font(.caption.bold()).foregroundStyle(.orange)
                }

                // Weight: +/- buttons AROUND the value, with the digital crown
                // as a power-user fast-scroll alternative. Crown step matches
                // the typical gym increment (2.5 kg / 5 lbs).
                weightStepper

                Divider()

                // Reps with +/- buttons
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

    // MARK: - Weight stepper

    /// Display unit (kg or lbs) increment used by both the +/- buttons and
    /// the digital crown. 2.5 kg / 5 lbs matches typical gym plate steps.
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

    /// Compact stepper button used for both reps and weight. Plain style so it
    /// doesn't fight the surrounding layout, with a haptic click on tap.
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
// On a tiny watch screen, search bars and keyboards are torture. This sheet
// shows tap-to-add common exercises first, then recent exercises pulled from
// the iPhone, then a dictation-only "custom" path as a last resort.

struct AddExerciseSheet: View {
    let recentExercises: [String]
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var customName = ""
    @State private var showingCustomEntry = false

    /// Hand-picked common gym lifts. Tappable directly — no typing needed.
    private let commonExercises: [String] = [
        "Bench Press", "Squat", "Deadlift", "Overhead Press",
        "Barbell Row", "Pull-up", "Dumbbell Press", "Lat Pulldown",
        "Bicep Curl", "Tricep Pushdown", "Leg Press", "Lunges",
        "Hip Thrust", "Romanian Deadlift", "Lateral Raise", "Cable Row",
    ]

    /// Recents minus anything already in the common list (avoid duplicates).
    private var dedupedRecents: [String] {
        let common = Set(commonExercises.map { $0.lowercased() })
        return recentExercises.filter { !common.contains($0.lowercased()) }
    }

    var body: some View {
        List {
            // Recents at top — most likely what the user wants
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

/// Tiny sheet for the rare case where the user really wants to type a name.
/// Uses watchOS's TextField (which auto-prompts dictation), avoiding the
/// painful inline `.searchable` keyboard.
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
