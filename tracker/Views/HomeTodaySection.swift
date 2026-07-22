import SwiftUI

/// The redesigned head of Home: brand row → 14-day effort tape → today's
/// verdict → the session on deck.
///
/// Everything here binds to data the app already computes. There is no new
/// engine: the design's "scenario" model (primed / strained / rest day) is
/// presentation state derived from `TodayPlan` + `RecoveryEngine` output, and
/// the mapping lives in `HomeTodayData`.
struct HomeTodaySection: View {
    let data: HomeTodayData
    let plan: TodayPlan
    let onOpenPlanDetail: () -> Void
    let onStart: () -> Void
    let onSelectDay: (Workout) -> Void

    private var accent: Color { AppTheme.Dark.accent(for: plan.intensity) }

    var body: some View {
        VStack(spacing: 14) {
            brandRow
                .padding(.horizontal, 18)

            EffortTape(
                days: data.tapeDays,
                totalVolumeK: data.totalVolumeK,
                sessionCount: data.sessionCount,
                accent: accent,
                onSelectDay: onSelectDay
            )

            TodayHero(
                plan: plan,
                signals: data.signals,
                caveat: data.caveat,
                caveatColor: data.caveatColor,
                isFirstSession: data.isFirstSession,
                onTap: onOpenPlanDetail
            )
            .padding(.horizontal, 12)

            NextUpCard(
                eyebrow: data.nextUp.eyebrow,
                meta: data.nextUp.meta,
                workoutName: data.nextUp.workoutName,
                exercises: data.nextUp.exercises,
                accent: accent,
                ctaTitle: data.nextUp.ctaTitle,
                onOpenDetail: onOpenPlanDetail,
                onStart: onStart
            )
            .padding(.horizontal, 12)
        }
    }

    private var brandRow: some View {
        HStack {
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.Dark.Signal.recovery)
                    .frame(width: 8, height: 8)
                    .signalGlow(AppTheme.Dark.Signal.recovery)
                Text("METRICLY")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.6)
                    .foregroundStyle(AppTheme.Dark.text)
            }
            Spacer()
            // The prototype pairs this with a clock; the status bar already owns
            // the time, and a second one baked into a scroll view goes stale.
            Text("WK \(Calendar.current.component(.weekOfYear, from: .now))")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(0.8)
                .foregroundStyle(AppTheme.Dark.text3)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Data mapping

/// Everything the redesigned head of Home renders, derived once from the
/// snapshot rather than as six computed properties that each re-walk the
/// workout list on every body evaluation.
struct HomeTodayData {

    struct NextUp {
        var eyebrow: String
        var meta: String
        var workoutName: String
        var exercises: [NextUpCard.Exercise]
        var ctaTitle: String
    }

    var tapeDays: [EffortTape.Day] = []
    var totalVolumeK: Double = 0
    var sessionCount: Int = 0
    var signals: MicroSignalRow.Signals
    var caveat: String?
    var caveatColor: Color = AppTheme.Dark.Signal.caution
    /// No finished workout yet — the hero and the CTA both soften for day one.
    var isFirstSession: Bool = false
    var nextUp: NextUp

    // MARK: Build

    static func build(
        snapshot: HomeDashboardSnapshot,
        plan: TodayPlan,
        health: HealthSignals,
        sleepMinutes: Double,
        healthDataLoaded: Bool,
        progressionSuggestions: [HomeProgressionSuggestion]
    ) -> HomeTodayData {
        let tape = buildTape(snapshot: snapshot)
        let isFirstSession = !snapshot.allWorkouts.contains(where: \.isFinished)
        return HomeTodayData(
            tapeDays: tape.days,
            totalVolumeK: tape.totalVolumeK,
            sessionCount: tape.sessionCount,
            signals: buildSignals(
                health: health,
                sleepMinutes: sleepMinutes,
                loaded: healthDataLoaded,
                snapshot: snapshot
            ),
            caveat: buildCaveat(plan: plan),
            caveatColor: plan.avoidGroups.isEmpty
                ? AppTheme.Dark.Signal.calm
                : AppTheme.Dark.Signal.caution,
            isFirstSession: isFirstSession,
            nextUp: buildNextUp(
                snapshot: snapshot,
                plan: plan,
                progressionSuggestions: progressionSuggestions,
                isFirstSession: isFirstSession
            )
        )
    }

    // MARK: Tape

    /// Raw per-day facts, before classification — the kind of a day depends on
    /// how it compares to the rest of the window, so it can't be decided while
    /// walking the days one at a time.
    private struct RawDay {
        let date: Date
        let volumeK: Double
        let rpe: Double?
        let hasCardio: Bool
        let workout: Workout?
    }

    private static func buildTape(
        snapshot: HomeDashboardSnapshot
    ) -> (days: [EffortTape.Day], totalVolumeK: Double, sessionCount: Int) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let finished = snapshot.allWorkouts.filter(\.isFinished)

        let raw: [RawDay] = (1...14).reversed().compactMap { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: today),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
            let lifts = finished.filter { $0.date >= dayStart && $0.date < dayEnd }
            let hasCardio = snapshot.cardioSessions.contains { $0.date >= dayStart && $0.date < dayEnd }
            return RawDay(
                date: dayStart,
                volumeK: lifts.reduce(0) { $0 + $1.totalVolumeKg() } / 1000,
                rpe: averageRPE(of: lifts),
                hasCardio: hasCardio,
                workout: lifts.first
            )
        }

        // Volume tertiles across the window. Most users never log per-set RPE,
        // so effort is read from the user's own volume distribution rather than
        // an absolute scale that would call every one of their days "light".
        let volumes = raw.map(\.volumeK).filter { $0 > 0 }.sorted()
        let lowerThird = volumes.isEmpty ? 0 : volumes[volumes.count / 3]
        let upperThird = volumes.isEmpty ? 0 : volumes[(volumes.count * 2) / 3]

        var days = raw.map { day -> EffortTape.Day in
            let kind: EffortTape.Day.Kind
            if day.volumeK > 0 {
                kind = classify(volumeK: day.volumeK, rpe: day.rpe,
                                lowerThird: lowerThird, upperThird: upperThird)
            } else {
                kind = day.hasCardio ? .cardio : .rest
            }
            return EffortTape.Day(
                letter: String(day.date.formatted(.dateTime.weekday(.narrow))),
                kind: kind,
                volumeK: day.volumeK,
                rpe: day.rpe,
                date: day.date,
                workout: day.workout
            )
        }

        days.append(
            EffortTape.Day(
                letter: String(today.formatted(.dateTime.weekday(.narrow))),
                kind: .today,
                volumeK: 0,
                rpe: nil,
                date: today,
                workout: nil
            )
        )

        return (
            days,
            raw.reduce(0) { $0 + $1.volumeK },
            raw.filter { $0.volumeK > 0 || $0.hasCardio }.count
        )
    }

    private static func classify(
        volumeK: Double,
        rpe: Double?,
        lowerThird: Double,
        upperThird: Double
    ) -> EffortTape.Day.Kind {
        // Logged RPE wins when it's there — it's what the user actually felt.
        if let rpe {
            if rpe >= 8 { return .hard }
            if rpe >= 6.5 { return .moderate }
            return .light
        }
        if volumeK >= upperThird { return .hard }
        if volumeK >= lowerThird { return .moderate }
        return .light
    }

    /// Mean RPE over a day's working sets, or nil when none were logged.
    private static func averageRPE(of workouts: [Workout]) -> Double? {
        let values = workouts
            .flatMap(\.exercises)
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .compactMap(\.rpe)
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    // MARK: Signals

    private static func buildSignals(
        health: HealthSignals,
        sleepMinutes: Double,
        loaded: Bool,
        snapshot: HomeDashboardSnapshot
    ) -> MicroSignalRow.Signals {
        MicroSignalRow.Signals(
            hrv: hrvCell(health, loaded: loaded),
            rhr: rhrCell(health, loaded: loaded),
            sleep: sleepCell(sleepMinutes, loaded: loaded),
            strain: strainCell(snapshot)
        )
    }

    private static func hrvCell(_ health: HealthSignals, loaded: Bool) -> MicroSignalRow.Cell {
        guard loaded, let value = health.todayHRV else {
            return .placeholder(label: "HRV", unit: "ms", spoken: "Heart rate variability unavailable")
        }
        let delta = health.averageHRV.map { value - $0 }
        return MicroSignalRow.Cell(
            label: "HRV",
            value: "\(Int(value.rounded()))",
            unit: "ms",
            delta: formatDelta(delta, decimals: 0),
            color: tone(for: delta, higherIsBetter: true),
            accessibilityLabel: spoken(
                "Heart rate variability \(Int(value.rounded())) milliseconds",
                delta: delta, unit: "milliseconds", decimals: 0
            )
        )
    }

    private static func rhrCell(_ health: HealthSignals, loaded: Bool) -> MicroSignalRow.Cell {
        guard loaded, let value = health.todayRestingHR else {
            return .placeholder(label: "RHR", unit: "bpm", spoken: "Resting heart rate unavailable")
        }
        let delta = health.averageRestingHR.map { value - $0 }
        return MicroSignalRow.Cell(
            label: "RHR",
            value: "\(Int(value.rounded()))",
            unit: "bpm",
            delta: formatDelta(delta, decimals: 0),
            color: tone(for: delta, higherIsBetter: false),
            accessibilityLabel: spoken(
                "Resting heart rate \(Int(value.rounded())) beats per minute",
                delta: delta, unit: "beats per minute", decimals: 0
            )
        )
    }

    private static func sleepCell(_ minutes: Double, loaded: Bool) -> MicroSignalRow.Cell {
        guard loaded, minutes > 0 else {
            return .placeholder(label: "SLEEP", unit: "", spoken: "Sleep unavailable")
        }
        // No personal sleep baseline is stored, so this compares against the
        // same target the plan engine already uses rather than inventing one.
        let hours = minutes / 60
        let target = EngineConstants.TodayPlan.sleepGoodHours
        let deltaMinutes = Int((hours - target) * 60)
        let color: Color
        if hours >= target {
            color = AppTheme.Dark.Signal.recovery
        } else if hours >= EngineConstants.TodayPlan.sleepShortHours {
            color = AppTheme.Dark.Signal.caution
        } else {
            color = AppTheme.Dark.Signal.strain
        }
        return MicroSignalRow.Cell(
            label: "SLEEP",
            value: HealthFormatters.formatSleepShort(minutes),
            unit: "",
            delta: "\(deltaMinutes >= 0 ? "+" : "−")\(abs(deltaMinutes))m",
            color: color,
            accessibilityLabel: "Slept \(HealthFormatters.formatSleepShort(minutes)), "
                + "\(abs(deltaMinutes)) minutes \(deltaMinutes >= 0 ? "above" : "below") target"
        )
    }

    private static func strainCell(_ snapshot: HomeDashboardSnapshot) -> MicroSignalRow.Cell {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today) ?? today
        let fortnightAgo = calendar.date(byAdding: .day, value: -14, to: today) ?? today
        let finished = snapshot.allWorkouts.filter(\.isFinished)

        let thisWeek = finished
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.totalVolumeKg() } / 1000
        let lastWeek = finished
            .filter { $0.date >= fortnightAgo && $0.date < weekAgo }
            .reduce(0) { $0 + $1.totalVolumeKg() } / 1000
        let delta = lastWeek > 0 ? thisWeek - lastWeek : nil

        // A jump in load isn't failure, but it is the thing most likely to
        // explain a bad readiness score tomorrow — so a sharp rise reads amber.
        let color: Color = (lastWeek > 0 && thisWeek > lastWeek * 1.2)
            ? AppTheme.Dark.Signal.caution
            : AppTheme.Dark.Signal.recovery

        return MicroSignalRow.Cell(
            label: "STRAIN",
            value: String(format: "%.1f", thisWeek),
            unit: "k·kg",
            delta: formatDelta(delta, decimals: 1),
            color: color,
            accessibilityLabel: spoken(
                "7-day training volume \(String(format: "%.1f", thisWeek)) thousand kilograms",
                delta: delta, unit: "thousand kilograms", decimals: 1
            )
        )
    }

    private static func formatDelta(_ delta: Double?, decimals: Int) -> String {
        guard let delta else { return "—" }
        let magnitude = String(format: "%.\(decimals)f", abs(delta))
        return "\(delta >= 0 ? "+" : "−")\(magnitude)"
    }

    private static func spoken(_ base: String, delta: Double?, unit: String, decimals: Int) -> String {
        guard let delta else { return base }
        let magnitude = String(format: "%.\(decimals)f", abs(delta))
        return "\(base), \(magnitude) \(unit) \(delta >= 0 ? "above" : "below") baseline"
    }

    private static func tone(for delta: Double?, higherIsBetter: Bool) -> Color {
        guard let delta else { return AppTheme.Dark.text3 }
        let good = higherIsBetter ? delta >= 0 : delta <= 0
        return good ? AppTheme.Dark.Signal.recovery : AppTheme.Dark.Signal.caution
    }

    // MARK: Caveat

    /// One line explaining what the plan is working around today. Falls back to
    /// the engine's own top reason so the hero is never silent about *why*.
    private static func buildCaveat(plan: TodayPlan) -> String? {
        if let avoided = plan.avoidGroups.first {
            return "\(avoided.rawValue) overworked this week — flagged in today's session"
        }
        if let easy = plan.goEasyOnGroups.first {
            return "\(easy.rawValue) still recovering — keep it light there"
        }
        return plan.reasons.first
    }

    // MARK: Next up

    private static func buildNextUp(
        snapshot: HomeDashboardSnapshot,
        plan: TodayPlan,
        progressionSuggestions: [HomeProgressionSuggestion],
        isFirstSession: Bool
    ) -> NextUp {
        guard plan.intensity != .rest else {
            return NextUp(
                eyebrow: "TODAY · NOTHING REQUIRED",
                meta: "OPTIONAL · PICK ONE",
                workoutName: "Rest day",
                exercises: [],
                ctaTitle: "Log a recovery activity"
            )
        }

        let template = snapshot.templates.first {
            $0.name.localizedCaseInsensitiveCompare(plan.recommendedName) == .orderedSame
        }
        let exercises = template.map { buildExerciseRows($0, plan: plan, suggestions: progressionSuggestions) } ?? []

        // A swap is announced, not hidden. The user planned one thing and is
        // getting another; the eyebrow is where that gets said.
        let eyebrow: String
        if let scheduled = plan.scheduledName, !scheduled.isEmpty,
           scheduled.localizedCaseInsensitiveCompare(plan.recommendedName) != .orderedSame {
            eyebrow = "SWAPPED IN · WAS: \(scheduled.uppercased())"
        } else {
            eyebrow = "NEXT UP · TODAY"
        }

        let meta = exercises.isEmpty
            ? "NO TEMPLATE YET"
            : "\(exercises.count) LIFTS · ~\(estimatedMinutes(for: exercises)) MIN"

        return NextUp(
            eyebrow: eyebrow,
            meta: meta,
            workoutName: plan.recommendedName,
            exercises: exercises,
            // Day one has no named session worth quoting back — "Start Your
            // first workout" is what happens when you interpolate a placeholder.
            ctaTitle: isFirstSession ? "Start your first workout" : "Start \(plan.recommendedName)"
        )
    }

    private static func buildExerciseRows(
        _ template: Workout,
        plan: TodayPlan,
        suggestions: [HomeProgressionSuggestion]
    ) -> [NextUpCard.Exercise] {
        let easeGroups = Set(plan.goEasyOnGroups + plan.avoidGroups)
        let pushNames = Set(suggestions.map { $0.exerciseName.lowercased() })

        return template.exercises.sorted { $0.order < $1.order }.map { exercise in
            let workingSets = exercise.sets.filter { !$0.isWarmUp }
            let setCount = max(workingSets.count, 1)

            let hint: NextUpCard.Exercise.Hint?
            if let category = exercise.category, easeGroups.contains(category) {
                hint = .init(text: "Easy — go light", tone: .ease)
            } else if pushNames.contains(exercise.name.lowercased()) {
                hint = .init(text: "PR window", tone: .push)
            } else {
                hint = nil
            }

            return NextUpCard.Exercise(
                name: exercise.name,
                sets: "\(setCount) × \(modeReps(of: workingSets))",
                setCount: setCount,
                hint: hint
            )
        }
    }

    /// The rep count the template repeats most — a "4 × 5" reads better than
    /// averaging a 5/5/5/8 top set into "4 × 5.75".
    private static func modeReps(of sets: [ExerciseSet]) -> Int {
        let reps = sets.map(\.reps).filter { $0 > 0 }
        guard !reps.isEmpty else { return 0 }
        let counts = Dictionary(grouping: reps, by: { $0 }).mapValues(\.count)
        return counts.max { ($0.value, $1.key) < ($1.value, $0.key) }?.key ?? reps[0]
    }

    /// Rough session length: working sets plus their rest, and a warm-up.
    /// Deliberately coarse — the card says "~58 MIN", not a promise.
    private static func estimatedMinutes(for exercises: [NextUpCard.Exercise]) -> Int {
        let sets = exercises.reduce(0) { $0 + $1.setCount }
        let minutes = 8 + Int(Double(sets) * 3.0)
        return max(10, (minutes / 5) * 5)
    }
}

private extension MicroSignalRow.Cell {
    /// Shown when HealthKit hasn't produced a value yet — an em dash rather
    /// than a zero, because "0 ms HRV" is a lie and "—" is a fact.
    static func placeholder(label: String, unit: String, spoken: String) -> MicroSignalRow.Cell {
        MicroSignalRow.Cell(
            label: label,
            value: "—",
            unit: unit,
            delta: "—",
            color: AppTheme.Dark.text3,
            accessibilityLabel: spoken
        )
    }
}
