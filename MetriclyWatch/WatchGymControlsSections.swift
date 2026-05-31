import SwiftUI
import WatchKit

// MARK: - Active workout

extension WatchGymView {

    var activeView: some View {
        VStack(spacing: 0) {
            hrBanner

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingControls = true
                } label: {
                    Image(systemName: sessionManager.isPaused
                          ? "pause.circle.fill"
                          : "ellipsis.circle.fill")
                        .foregroundStyle(sessionManager.isPaused ? .yellow : .green)
                }
                .accessibilityLabel("Workout controls")
            }
        }
        .confirmationDialog(
            "Workout",
            isPresented: $showingControls,
            titleVisibility: .visible
        ) {
            Button("Finish Workout") { showingFinish = true }
            Button(sessionManager.isPaused ? "Resume" : "Pause") {
                if sessionManager.isPaused {
                    sessionManager.resume()
                } else {
                    sessionManager.pause()
                }
            }
            Button("Water Lock") { WKInterfaceDevice.current().enableWaterLock() }
            Button("Discard Workout", role: .destructive) {
                showingDiscardConfirm = true
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Discard workout?",
            isPresented: $showingDiscardConfirm,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) { discardWorkout() }
            Button("Keep Going", role: .cancel) {}
        } message: {
            Text("All sets from this workout will be lost.")
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

    var hrBanner: some View {
        NavigationLink {
            WatchActiveMetricsView(
                exercises: exercises,
                useKg: connectivity.useKg
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "heart.fill")
                    .font(.caption.bold())
                    .foregroundStyle(hrColor)
                    .symbolEffect(.pulse.byLayer, options: .repeating, isActive: sessionManager.heartRate > 0)
                Text(sessionManager.heartRate > 0 ? "\(Int(sessionManager.heartRate))" : "--")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit()
                if sessionManager.heartRate > 0 {
                    Text(sessionManager.heartRateZone.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(hrColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(hrColor.opacity(0.18), in: Capsule())
                }
                let setCount = workingSetCount
                if setCount > 0 {
                    Text("● \(setCount)")
                        .font(.system(size: 11, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.green)
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
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(bannerAccessibilityLabel)
        .accessibilityHint("Opens live workout metrics")
    }

    var workingSetCount: Int {
        exercises.flatMap(\.sets).filter { !$0.isWarmUp }.count
    }

    var bannerAccessibilityLabel: String {
        var parts: [String] = []
        if sessionManager.heartRate > 0 {
            parts.append("Heart rate \(Int(sessionManager.heartRate)) BPM, \(sessionManager.heartRateZone.rawValue) zone")
        } else {
            parts.append("Heart rate pending")
        }
        let n = workingSetCount
        if n > 0 { parts.append("\(n) \(n == 1 ? "set" : "sets") logged") }
        parts.append("elapsed \(formatDuration(sessionManager.elapsedSeconds))")
        return parts.joined(separator: ", ")
    }

    func exerciseRow(_ exercise: WatchExerciseRecord) -> some View {
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
            if !workingSets.isEmpty {
                Text("\(workingSets.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.green)
                    .frame(minWidth: 20)
            }
        }
    }

    func rowSubtitle(workingSets: [WatchSetRecord], last: WatchSetRecord?) -> String {
        guard let last else { return "Tap to log" }
        return "Last: \(last.reps) × \(formatWeight(last.weightKg, useKg: connectivity.useKg))"
    }

    var hrColor: Color {
        switch sessionManager.heartRateZone {
        case .resting: return .gray
        case .fat:     return .blue
        case .cardio:  return .green
        case .peak:    return .orange
        case .max:     return .red
        }
    }
}
