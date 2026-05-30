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
    @Query(sort: \SorenessEntry.date, order: .reverse) private var sorenessReports: [SorenessEntry]
    @State private var externalWorkouts: [ExternalWorkout] = []
    @State private var recoveryResult: RecoveryResult = .empty

    private func recomputeRecovery() {
        recoveryResult = RecoveryEngine.evaluate(
            workouts: workouts,
            health: HealthSignals(
                todayHRV: latestHRV,
                averageHRV: averageHRV,
                todayRestingHR: todayRestingHR,
                averageRestingHR: averageRestingHR,
                sleepMinutes: healthDataLoaded ? lastNightSleep : nil
            ),
            externalWorkouts: externalWorkouts,
            cardioSessions: Array(cardioSessions.prefix(50)),
            sorenessReports: Array(sorenessReports.prefix(30))
        )
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                if !externalWorkouts.isEmpty {
                    externalActivityCard
                }
                if !activeSorenessReports.isEmpty {
                    sorenessReportsCard
                }
                muscleGroupsCard
                suggestedCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(String(
            localized: "Recovery",
            comment: "Navigation title for the muscle recovery / readiness screen"
        ))
        .task {
            guard settingsArray.first?.healthKitEnabled == true else { return }
            let hk = HealthDataCache.shared
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
            recomputeRecovery()
        }
        .onChange(of: workouts) { recomputeRecovery() }
        .onChange(of: cardioSessions) { recomputeRecovery() }
        .onChange(of: sorenessReports) { recomputeRecovery() }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        let score = recoveryResult.readinessScore
        let palette: [Color] = score >= 0.70
            ? AppTheme.Gradients.recovery
            : (score >= 0.45 ? AppTheme.Gradients.caution : AppTheme.Gradients.strain)

        return HeroCard(palette: palette) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: score)
                            .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: score)
                            .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                    }
                    .frame(width: 72, height: 72)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(
                            localized: "Overall Readiness",
                            comment: "Hero label above the recovery readiness percentage"
                        ))
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            AnimatedInt(
                                value: Int(score * 100),
                                font: .system(size: 56, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                            Text("%")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                }

                Text(RecoveryEngine.readinessLabel(score))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))

                Text(healthDataLoaded
                    ? String(localized: "Based on workouts, sleep, heart rate & HRV",
                             comment: "Hero subtitle shown when HealthKit data is loaded")
                    : String(localized: "Based on recent workouts and training volume",
                             comment: "Hero subtitle shown when HealthKit data is not yet loaded"))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.78))

                if healthDataLoaded && !availableSignals.isEmpty {
                    Rectangle()
                        .fill(.white.opacity(0.16))
                        .frame(height: 1)
                    heroSignalStrip
                }
            }
            .padding(20)
        }
        // Merge the score, "%", and readiness label into a single VO
        // utterance instead of three stops. Previously this passed
        // `readinessColor.description` as a hint, which reads out the raw
        // SwiftUI debug string ("Color(red: ...)") via VoiceOver.
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(
            localized: "Overall readiness \(Int(score * 100)) percent. \(RecoveryEngine.readinessLabel(score))",
            comment: "VoiceOver label for the recovery hero card combining the numeric score and the readiness sentence"
        ))
    }

    // MARK: - Hero Signal Strip

    /// The HRV / Resting HR / Sleep signals that feed the readiness
    /// score, surfaced inline in the hero (mirroring the Home hero) so
    /// the number is explainable at a glance. Each value carries its
    /// traffic-light dot. This replaced the separate "Health Factors"
    /// card, which duplicated the same three metrics one card below the
    /// hero — the strip folds that card's signal into the hero itself.
    private var availableSignals: [HeroSignal] {
        var out: [HeroSignal] = []
        if let hrv = latestHRV {
            out.append(HeroSignal(value: "\(Int(hrv)) ms", label: "HRV", dot: AnyView(hrvIndicator)))
        }
        if let rhr = todayRestingHR {
            out.append(HeroSignal(value: "\(Int(rhr)) bpm", label: "Resting HR", dot: AnyView(rhrIndicator)))
        }
        if lastNightSleep > 0 {
            let h = Int(lastNightSleep) / 60, m = Int(lastNightSleep) % 60
            out.append(HeroSignal(value: "\(h)h \(m)m", label: "Sleep", dot: AnyView(sleepIndicator)))
        }
        return out
    }

    private struct HeroSignal: Identifiable {
        let id = UUID()
        let value: String
        let label: String
        let dot: AnyView
    }

    private var heroSignalStrip: some View {
        HStack(spacing: 0) {
            ForEach(Array(availableSignals.enumerated()), id: \.element.id) { index, sig in
                if index > 0 {
                    Rectangle()
                        .fill(.white.opacity(0.22))
                        .frame(width: 1, height: 30)
                }
                VStack(spacing: 4) {
                    Text(sig.value)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    HStack(spacing: 4) {
                        sig.dot
                        Text(sig.label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .tracking(0.4)
                            .textCase(.uppercase)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Health Indicators

    @ViewBuilder
    private var hrvIndicator: some View {
        if let hrv = latestHRV, let avg = averageHRV, avg > 0 {
            let ratio = hrv / avg
            Circle()
                .fill(healthTint(ratio >= 1.0 ? .good : ratio >= 0.85 ? .borderline : .bad))
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var rhrIndicator: some View {
        if let rhr = todayRestingHR, let avg = averageRestingHR, avg > 0 {
            let ratio = rhr / avg
            Circle()
                .fill(healthTint(ratio <= 1.05 ? .good : ratio <= 1.10 ? .borderline : .bad))
                .frame(width: 10, height: 10)
        }
    }

    @ViewBuilder
    private var sleepIndicator: some View {
        let hours = lastNightSleep / 60
        Circle()
            .fill(healthTint(hours >= 7 ? .good : hours >= 6 ? .borderline : .bad))
            .frame(width: 10, height: 10)
    }

    /// Three-state traffic light tinting for the HRV/RHR/Sleep dots.
    /// Pulled through AppTheme so a future palette tweak ripples
    /// through every indicator at once.
    private enum HealthState { case good, borderline, bad }
    private func healthTint(_ state: HealthState) -> Color {
        switch state {
        case .good:       return AppTheme.Signal.recovery
        case .borderline: return AppTheme.Signal.warning
        case .bad:        return AppTheme.Signal.caution
        }
    }

    // MARK: - External Activity Card

    private var externalActivityCard: some View {
        GroupedListCard(
            title: String(localized: "External Activity",
                          comment: "Section header above the list of workouts pulled from HealthKit / Strava"),
            icon: "figure.run",
            color: .orange
        ) {
            ForEach(Array(externalWorkouts.prefix(5).enumerated()), id: \.element.id) { idx, workout in
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.orange, AppTheme.Signal.actionOrange],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .shadow(color: .orange.opacity(0.40), radius: 5, y: 2)
                            Image(systemName: workout.icon)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(workout.displayName)
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            HStack(spacing: 6) {
                                Text(workout.sourceName)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                if workout.duration > 0 {
                                    Text(formatDuration(workout.duration))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                if let dist = workout.totalDistance, dist > 0 {
                                    Text(String(format: "%.1f %@",
                                         weightUnit.distanceUnit.display(dist / 1000),
                                         weightUnit.distanceUnit.label))
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        Spacer()
                        Text(workout.startDate, style: .relative)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < min(externalWorkouts.count, 5) - 1 {
                        Divider().padding(.leading, 64)
                    }
                }
        }
    }

    // MARK: - Soreness Reports
    //
    // Shows the most-recent self-report per muscle group within the
    // engine's 48h lookback window. Makes the soreness signal visible
    // — without this, a user wonders why "legs" is red even though
    // their objective fatigue numbers look OK.

    /// The latest report per group within the 48h window. One row per
    /// affected group, level > 0 only (level 0 = "no soreness" and
    /// doesn't warrant a row).
    private var activeSorenessReports: [SorenessEntry] {
        let cutoff = Date.now.addingTimeInterval(-EngineConstants.Recovery.sorenessLookbackHours * 3600)
        var seen = Set<MuscleGroup>()
        return sorenessReports
            .filter { $0.date >= cutoff && $0.level > 0 }
            .filter { entry in
                guard !seen.contains(entry.group) else { return false }
                seen.insert(entry.group)
                return true
            }
    }

    private var sorenessReportsCard: some View {
        GroupedListCard(
            title: String(localized: "Reported Soreness",
                          comment: "Section header above the user's recent post-workout soreness reports"),
            icon: "figure.cooldown",
            color: .purple,
            footnote: String(localized: "From your post-workout check-in. Counts for 48 hours.",
                             comment: "Footnote under the Reported Soreness section")
        ) {
            ForEach(Array(activeSorenessReports.enumerated()), id: \.element.id) { idx, report in
                sorenessRow(report)
                if idx < activeSorenessReports.count - 1 {
                    Divider().padding(.leading, 52)
                }
            }
        }
    }

    private func sorenessRow(_ report: SorenessEntry) -> some View {
        let level = SorenessEntry.Level(rawValue: max(0, min(4, report.level))) ?? .none
        let tint = sorenessTint(for: report.level)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.26), tint.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(tint.opacity(0.28), lineWidth: 0.5))
                Image(systemName: level.sfSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(report.group.rawValue)
                    .font(.subheadline.weight(.semibold))
                Text(level.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(report.date.formatted(.relative(presentation: .named, unitsStyle: .abbreviated)))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }

    private func sorenessTint(for level: Int) -> Color {
        SorenessEntry.Level.tint(forLevel: level)
    }

    // MARK: - Muscle Groups Card

    /// Per-muscle freshness sorted most-recovered first, matching the
    /// Home muscle-readiness section so the ranking reads the same on
    /// both surfaces (train from the top, protect the bottom).
    private var sortedMuscleResults: [MuscleFatigueResult] {
        recoveryResult.muscleResults.sorted { $0.freshness > $1.freshness }
    }

    private var muscleGroupsCard: some View {
        GroupedListCard(
            title: String(localized: "By Muscle Group",
                          comment: "Section header above the per-muscle freshness breakdown"),
            icon: "figure.strengthtraining.traditional",
            color: .accentColor
        ) {
            ForEach(Array(sortedMuscleResults.enumerated()), id: \.element.id) { idx, result in
                muscleRow(result)
                if idx < sortedMuscleResults.count - 1 {
                    Divider().padding(.leading, 62)
                }
            }
        }
    }

    private func muscleRow(_ result: MuscleFatigueResult) -> some View {
        let color = RecoveryEngine.freshnessColor(result.freshness)
        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.20), color.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(color.opacity(0.20), lineWidth: 0.5))
                MuscleIconView(group: result.group, color: color)
                    .frame(width: 18, height: 18)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(result.group.rawValue)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Spacer()
                    Text(RecoveryEngine.freshnessLabel(result.freshness).uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.4)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: Capsule()
                        )
                        .shadow(color: color.opacity(0.40), radius: 4, y: 2)
                }
                GradientProgressBar(value: result.freshness, color: color, height: 7)
                if let last = result.lastTrained {
                    Text(RecoveryEngine.timeAgoText(from: last))
                        .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Text(String(
                        localized: "Not trained recently",
                        comment: "Shown in the by-muscle breakdown when the muscle hasn't been trained in the lookback window"
                    ))
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Suggested Today Card

    private var suggestedCard: some View {
        let ready = recoveryResult.muscleResults.filter { $0.freshness >= 0.8 }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: String(localized: "Suggested Today",
                              comment: "Section header above the engine's per-muscle 'train this' recommendations"),
                icon: "checkmark.circle.fill", color: .green
            )

            if ready.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)
                            .shadow(color: .orange.opacity(0.40), radius: 6, y: 3)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    Text(String(
                        localized: "All muscles are still recovering. Consider a rest day or light cardio.",
                        comment: "Shown under Suggested Today when every muscle group is below the ready threshold"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(ready) { result in
                        HStack(spacing: 9) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.green.opacity(0.30), Color.green.opacity(0.14)],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color.green.opacity(0.30), lineWidth: 0.5))
                                MuscleIconView(group: result.group, color: .green)
                                    .frame(width: 14, height: 14)
                            }
                            Text(result.group.rawValue)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).padding(.vertical, 9)
                        .background(
                            LinearGradient(
                                colors: [Color.green.opacity(0.16), Color.green.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.green.opacity(0.20), lineWidth: 0.5)
                        )
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
