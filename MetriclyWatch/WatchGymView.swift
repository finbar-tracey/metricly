import SwiftUI
import HealthKit

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
            VStack(spacing: 12) {
                // Today's plan hint
                if !connectivity.todayPlanName.isEmpty {
                    Text(connectivity.todayPlanName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button {
                    startWorkout()
                } label: {
                    Label("Start Gym", systemImage: "dumbbell.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                if !connectivity.recentExercises.isEmpty {
                    Divider()
                    Text("Recent Exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle("Gym")
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

                Button {
                    showingFinish = true
                } label: {
                    Label("Finish Workout", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle(workoutName)
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
            Text(sessionManager.heartRate > 0 ? "\(Int(sessionManager.heartRate))" : "--")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
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
        VStack(alignment: .leading, spacing: 2) {
            Text(exercise.name)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(exercise.sets.isEmpty
                 ? "No sets yet"
                 : "\(exercise.sets.filter { !$0.isWarmUp }.count) sets")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private func startWorkout() {
        startDate     = .now
        exercises     = []
        workoutName   = connectivity.todayPlanName.isEmpty
            ? "Workout" : connectivity.todayPlanName

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
    @State private var weightFocused = false

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if isWarmUp {
                    Text("Warm-up").font(.caption.bold()).foregroundStyle(.orange)
                }

                // Weight (crown scrolls in display unit; stored always in kg)
                VStack(spacing: 4) {
                    let displayWeight = useKg ? weightKg : weightKg * 2.20462
                    Text(String(format: displayWeight.truncatingRemainder(dividingBy: 1) == 0 ? "%.0f" : "%.1f", displayWeight))
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .focusable(true, onFocusChange: { focused in weightFocused = focused })
                        .digitalCrownRotation(
                            $crownWeight,
                            from: 0, through: useKg ? 500 : 1100, by: useKg ? 2.5 : 5,
                            sensitivity: .low,
                            isContinuous: false
                        )
                        .onChange(of: crownWeight) { _, v in
                            // Crown value is in display unit; convert back to kg for storage
                            weightKg = useKg ? max(0, v) : max(0, v / 2.20462)
                        }
                        .onAppear { crownWeight = useKg ? weightKg : weightKg * 2.20462 }
                    Text(useKg ? "kg" : "lb").font(.caption).foregroundStyle(.secondary)
                }

                Divider()

                // Reps
                HStack(spacing: 16) {
                    Button { reps = max(1, reps - 1) } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 2) {
                        Text("\(reps)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("reps").font(.caption2).foregroundStyle(.secondary)
                    }

                    Button { reps += 1 } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }

                Button {
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
}

// MARK: - AddExerciseSheet

struct AddExerciseSheet: View {
    let recentExercises: [String]
    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filtered: [String] {
        searchText.isEmpty ? recentExercises
            : recentExercises.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            if !searchText.isEmpty {
                Button {
                    onAdd(searchText.capitalized)
                    dismiss()
                } label: {
                    Label("Add \"\(searchText.capitalized)\"", systemImage: "plus")
                        .foregroundStyle(.blue)
                }
            }
            ForEach(filtered, id: \.self) { name in
                Button(name) {
                    onAdd(name)
                    dismiss()
                }
            }
        }
        .searchable(text: $searchText)
        .navigationTitle("Exercise")
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
