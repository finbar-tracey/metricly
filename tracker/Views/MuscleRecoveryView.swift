import SwiftUI
import SwiftData

struct MuscleRecoveryView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit

    @State private var lastNightSleep: Double = 0
    @State private var latestHRV: Double?
    @State private var averageHRV: Double?
    @State private var todayRestingHR: Double?
    @State private var averageRestingHR: Double?
    @State private var healthDataLoaded = false
    @State private var externalWorkouts: [ExternalWorkout] = []

    private var recoveryResult: RecoveryResult {
        RecoveryEngine.evaluate(
            workouts: workouts,
            health: HealthSignals(
                todayHRV: latestHRV,
                averageHRV: averageHRV,
                todayRestingHR: todayRestingHR,
                averageRestingHR: averageRestingHR,
                sleepMinutes: healthDataLoaded ? lastNightSleep : nil
            ),
            externalWorkouts: externalWorkouts
        )
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Muscle Readiness")
                        .font(.headline)
                    Text(healthDataLoaded
                        ? "Based on your workouts, sleep, heart rate, and HRV."
                        : "Based on your recent workouts and training volume.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    readinessOverview
                }
                .padding(.vertical, 4)
            }

            if healthDataLoaded && (latestHRV != nil || lastNightSleep > 0 || todayRestingHR != nil) {
                Section("Health Factors") {
                    if let hrv = latestHRV {
                        HStack {
                            Label("HRV", systemImage: "waveform.path.ecg")
                            Spacer()
                            Text("\(Int(hrv)) ms")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            hrvIndicator
                        }
                    }
                    if let rhr = todayRestingHR {
                        HStack {
                            Label("Resting HR", systemImage: "heart.fill")
                            Spacer()
                            Text("\(Int(rhr)) bpm")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            rhrIndicator
                        }
                    }
                    if lastNightSleep > 0 {
                        HStack {
                            Label("Sleep", systemImage: "bed.double.fill")
                            Spacer()
                            let h = Int(lastNightSleep) / 60
                            let m = Int(lastNightSleep) % 60
                            Text("\(h)h \(m)m")
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            sleepIndicator
                        }
                    }
                }
            }

            if !externalWorkouts.isEmpty {
                Section("External Activity") {
                    ForEach(externalWorkouts.prefix(5)) { workout in
                        HStack(spacing: 12) {
                            Image(systemName: workout.icon)
                                .font(.title3)
                                .foregroundStyle(.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(workout.displayName)
                                    .font(.subheadline.weight(.medium))
                                HStack(spacing: 8) {
                                    Text(workout.sourceName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if workout.duration > 0 {
                                        Text(formatDuration(workout.duration))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let distance = workout.totalDistance, distance > 0 {
                                        Text(String(format: "%.1f %@", weightUnit.distanceUnit.display(distance / 1000), weightUnit.distanceUnit.label))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer()
                            Text(workout.startDate, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("By Muscle Group") {
                ForEach(recoveryResult.muscleResults) { result in
                    muscleRow(result)
                }
            }

            Section("Suggested Today") {
                let ready = recoveryResult.muscleResults.filter { $0.freshness >= 0.8 }
                if ready.isEmpty {
                    Text("All muscles are still recovering. Consider a rest day or light cardio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(ready) { result in
                        Label(result.group.rawValue, systemImage: result.group.icon)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .navigationTitle("Recovery")
        .task {
            guard settingsArray.first?.healthKitEnabled == true else { return }
            let hk = HealthKitManager.shared

            async let hrvResult = hk.fetchHRV(for: .now)
            async let hrvHistoryResult = hk.fetchDailyHRV(days: 7)
            async let sleepResult = hk.fetchSleep(for: .now)
            async let rhrResult = hk.fetchRestingHeartRate(for: .now)
            async let rhrHistoryResult = hk.fetchDailyRestingHeartRate(days: 7)
            async let externalResult = hk.fetchExternalWorkouts(days: 7)

            latestHRV = try? await hrvResult
            let hrvHistory = (try? await hrvHistoryResult) ?? []
            if !hrvHistory.isEmpty {
                averageHRV = hrvHistory.map(\.ms).reduce(0, +) / Double(hrvHistory.count)
            }
            let sleep = try? await sleepResult
            lastNightSleep = sleep?.totalMinutes ?? 0
            todayRestingHR = try? await rhrResult
            let rhrHistory = (try? await rhrHistoryResult) ?? []
            if !rhrHistory.isEmpty {
                averageRestingHR = rhrHistory.map(\.bpm).reduce(0, +) / Double(rhrHistory.count)
            }
            externalWorkouts = (try? await externalResult) ?? []
            healthDataLoaded = true
        }
    }

    // MARK: - Health Indicators

    @ViewBuilder
    private var hrvIndicator: some View {
        if let hrv = latestHRV, let avg = averageHRV, avg > 0 {
            let ratio = hrv / avg
            Circle()
                .fill(ratio >= 1.0 ? Color.green : ratio >= 0.85 ? Color.yellow : Color.orange)
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var rhrIndicator: some View {
        if let rhr = todayRestingHR, let avg = averageRestingHR, avg > 0 {
            let ratio = rhr / avg
            Circle()
                .fill(ratio <= 1.05 ? Color.green : ratio <= 1.10 ? Color.yellow : Color.orange)
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var sleepIndicator: some View {
        let hours = lastNightSleep / 60
        Circle()
            .fill(hours >= 7 ? Color.green : hours >= 6 ? Color.yellow : Color.orange)
            .frame(width: 10, height: 10)
    }

    // MARK: - Readiness Overview

    private var readinessOverview: some View {
        let score = recoveryResult.readinessScore
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: score)
                    .stroke(RecoveryEngine.readinessColor(score), style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(score * 100))")
                        .font(.title.bold())
                    Text("%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            VStack(alignment: .leading, spacing: 4) {
                Text("Overall Readiness")
                    .font(.subheadline.bold())
                Text(RecoveryEngine.readinessLabel(score))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 {
            let h = mins / 60
            let m = mins % 60
            return "\(h)h \(m)m"
        }
        return "\(mins)m"
    }

    // MARK: - Muscle Row

    private func muscleRow(_ result: MuscleFatigueResult) -> some View {
        HStack(spacing: 14) {
            Image(systemName: result.group.icon)
                .font(.title3)
                .foregroundStyle(RecoveryEngine.freshnessColor(result.freshness))
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(result.group.rawValue)
                    .font(.subheadline.weight(.medium))

                ProgressView(value: result.freshness)
                    .tint(RecoveryEngine.freshnessColor(result.freshness))

                if let last = result.lastTrained {
                    Text(RecoveryEngine.timeAgoText(from: last))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not trained recently")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(RecoveryEngine.freshnessLabel(result.freshness))
                .font(.caption.bold())
                .foregroundStyle(RecoveryEngine.freshnessColor(result.freshness))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        MuscleRecoveryView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
