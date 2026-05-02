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
    @Query(sort: \CardioSession.date, order: .reverse) private var cardioSessions: [CardioSession]
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
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50))
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                if healthDataLoaded && (latestHRV != nil || lastNightSleep > 0 || todayRestingHR != nil) {
                    healthFactorsCard
                }
                if !externalWorkouts.isEmpty {
                    externalActivityCard
                }
                muscleGroupsCard
                suggestedCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
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
            if !hrvHistory.isEmpty { averageHRV = hrvHistory.map(\.ms).reduce(0, +) / Double(hrvHistory.count) }
            let sleep = try? await sleepResult
            lastNightSleep = sleep?.totalMinutes ?? 0
            todayRestingHR = try? await rhrResult
            let rhrHistory = (try? await rhrHistoryResult) ?? []
            if !rhrHistory.isEmpty { averageRestingHR = rhrHistory.map(\.bpm).reduce(0, +) / Double(rhrHistory.count) }
            externalWorkouts = (try? await externalResult) ?? []
            healthDataLoaded = true
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let score = recoveryResult.readinessScore
        let readinessColor = RecoveryEngine.freshnessColor(score)

        return ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [readinessColor, readinessColor.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 200)
                .offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: score)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(score * 100))")
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("%")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Text("Overall Readiness")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                Text(RecoveryEngine.readinessLabel(score))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.20), in: Capsule())

                Text(healthDataLoaded
                    ? "Based on workouts, sleep, heart rate & HRV"
                    : "Based on recent workouts and training volume")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.70))
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Health Factors Card

    private var healthFactorsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Health Factors", icon: "waveform.path.ecg", color: .purple)

            VStack(spacing: 0) {
                if let hrv = latestHRV {
                    healthRow(icon: "waveform.path.ecg", color: .purple, label: "HRV",
                              value: "\(Int(hrv)) ms", indicator: hrvIndicator)
                    Divider().padding(.leading, 16)
                }
                if let rhr = todayRestingHR {
                    healthRow(icon: "heart.fill", color: .red, label: "Resting HR",
                              value: "\(Int(rhr)) bpm", indicator: rhrIndicator)
                    if lastNightSleep > 0 { Divider().padding(.leading, 16) }
                }
                if lastNightSleep > 0 {
                    let h = Int(lastNightSleep) / 60, m = Int(lastNightSleep) % 60
                    healthRow(icon: "bed.double.fill", color: .indigo, label: "Sleep",
                              value: "\(h)h \(m)m", indicator: sleepIndicator)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func healthRow(icon: String, color: Color, label: String, value: String, indicator: some View) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
            }
            Text(label).font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
            indicator
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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

    // MARK: - External Activity Card

    private var externalActivityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "External Activity", icon: "figure.run", color: .orange)

            VStack(spacing: 0) {
                ForEach(Array(externalWorkouts.prefix(5).enumerated()), id: \.element.id) { idx, workout in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.orange.opacity(0.12)).frame(width: 36, height: 36)
                            Image(systemName: workout.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(workout.displayName).font(.subheadline.weight(.medium))
                            HStack(spacing: 6) {
                                Text(workout.sourceName).font(.caption2).foregroundStyle(.secondary)
                                if workout.duration > 0 {
                                    Text(formatDuration(workout.duration)).font(.caption2).foregroundStyle(.secondary)
                                }
                                if let dist = workout.totalDistance, dist > 0 {
                                    Text(String(format: "%.1f %@",
                                         weightUnit.distanceUnit.display(dist / 1000),
                                         weightUnit.distanceUnit.label))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Text(workout.startDate, style: .relative)
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < min(externalWorkouts.count, 5) - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Muscle Groups Card

    private var muscleGroupsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "By Muscle Group", icon: "figure.strengthtraining.traditional", color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(recoveryResult.muscleResults.enumerated()), id: \.element.id) { idx, result in
                    muscleRow(result)
                    if idx < recoveryResult.muscleResults.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func muscleRow(_ result: MuscleFatigueResult) -> some View {
        let color = RecoveryEngine.freshnessColor(result.freshness)
        return HStack(spacing: 14) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 36, height: 36)
                MuscleIconView(group: result.group, color: color)
                    .frame(width: 16, height: 16)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(result.group.rawValue).font(.subheadline.weight(.medium))
                    Spacer()
                    Text(RecoveryEngine.freshnessLabel(result.freshness))
                        .font(.caption.bold())
                        .foregroundStyle(color)
                }
                GradientProgressBar(value: result.freshness, color: color, height: 5)
                if let last = result.lastTrained {
                    Text(RecoveryEngine.timeAgoText(from: last))
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text("Not trained recently")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Suggested Today Card

    private var suggestedCard: some View {
        let ready = recoveryResult.muscleResults.filter { $0.freshness >= 0.8 }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Suggested Today", icon: "checkmark.circle.fill", color: .green)

            if ready.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color.orange.opacity(0.12)).frame(width: 40, height: 40)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                    }
                    Text("All muscles are still recovering. Consider a rest day or light cardio.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(ready) { result in
                        HStack(spacing: 8) {
                            MuscleIconView(group: result.group, color: .green)
                                .frame(width: 14, height: 14)
                            Text(result.group.rawValue)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        if mins >= 60 { let h = mins / 60; let m = mins % 60; return "\(h)h \(m)m" }
        return "\(mins)m"
    }
}

#Preview {
    NavigationStack { MuscleRecoveryView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
