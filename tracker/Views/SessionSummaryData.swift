import SwiftUI

/// Everything `SessionSummaryView` renders, derived once from the saved workout.
/// The design's "finish" scenario is presentation state over the committed
/// session + `TodayPlan`, not a new engine.
struct SessionSummaryData {

    struct Stat: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let unit: String
        let decimals: Int
        var spokenValue: String {
            String(format: "%.\(decimals)f", value)
        }
    }

    var accent: Color
    var dateText: String
    var verdictA: String
    var verdictB: String
    var stats: [Stat]
    var highlight: String
    var costLine: String?
    var tomorrowLine: String?

    // MARK: - Build

    static func build(
        workout: Workout,
        allExercises: [Exercise],
        settings: UserSettings,
        weightUnit: WeightUnit,
        plan: TodayPlan?
    ) -> SessionSummaryData {
        let prs = FinishWorkoutSummarySection.sessionPRs(workout: workout, allExercises: allExercises)
        let working = workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }
        let volumeKg = working.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        let durationMin = (workout.duration ?? 0) / 60
        // A deload is the plan's call, not a shortfall — so it's praised, and the
        // whole screen takes the calmer "calm" accent rather than a hot one.
        let isDeload = plan.map { $0.intensity == .light || $0.intensity == .rest } ?? false
        let accent = isDeload ? AppTheme.Dark.Signal.calm : AppTheme.Dark.Signal.recovery

        return SessionSummaryData(
            accent: accent,
            dateText: workout.date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated)).uppercased(),
            verdictA: verdict(workout: workout, isDeload: isDeload, prCount: prs.count).0,
            verdictB: verdict(workout: workout, isDeload: isDeload, prCount: prs.count).1,
            stats: stats(volumeKg: volumeKg, durationMin: durationMin, working: working, prs: prs, weightUnit: weightUnit),
            highlight: highlight(prs: prs, isDeload: isDeload, working: working, volumeKg: volumeKg, weightUnit: weightUnit),
            costLine: costLine(workout: workout),
            tomorrowLine: tomorrowLine(settings: settings)
        )
    }

    // MARK: - Verdict

    private static func verdict(workout: Workout, isDeload: Bool, prCount: Int) -> (String, String) {
        if isDeload {
            return ("Smart deload,", "recovery protected.")
        }
        if prCount > 0 {
            return ("\(workout.name),", prCount == 1 ? "new PR banked." : "\(prCount) PRs banked.")
        }
        return ("\(workout.name),", "banked.")
    }

    // MARK: - Stats

    private static func stats(
        volumeKg: Double,
        durationMin: Double,
        working: [ExerciseSet],
        prs: [FinishWorkoutSessionPR],
        weightUnit: WeightUnit
    ) -> [Stat] {
        // Thousands of the user's own unit, so "14.6 k·kg" and "32.2 k·lb" both read true.
        let volumeK = weightUnit.display(volumeKg) / 1000
        let volumeUnit = weightUnit == .kg ? "k·kg" : "k·lb"

        var stats: [Stat] = [
            Stat(label: "VOLUME", value: volumeK, unit: volumeUnit, decimals: 1),
            Stat(label: "DURATION", value: durationMin.rounded(), unit: "min", decimals: 0),
            Stat(label: "SETS", value: Double(working.count), unit: "done", decimals: 0)
        ]

        // Fourth tile earns its place: a PR count when there were PRs, otherwise
        // the session's average RPE if it was logged — the light-day variant.
        if !prs.isEmpty {
            stats.append(Stat(label: "PRS", value: Double(prs.count), unit: prs.count == 1 ? "new" : "new", decimals: 0))
        } else {
            let rpes = working.compactMap(\.rpe)
            if !rpes.isEmpty {
                let avg = Double(rpes.reduce(0, +)) / Double(rpes.count)
                stats.append(Stat(label: "RPE AVG", value: avg, unit: "/10", decimals: 1))
            } else {
                stats.append(Stat(label: "PRS", value: 0, unit: "new", decimals: 0))
            }
        }
        return stats
    }

    // MARK: - Highlight

    private static func highlight(
        prs: [FinishWorkoutSessionPR],
        isDeload: Bool,
        working: [ExerciseSet],
        volumeKg: Double,
        weightUnit: WeightUnit
    ) -> String {
        if let top = prs.max(by: { $0.weight < $1.weight }) {
            return "\(top.exerciseName) \(weightUnit.formatShort(top.weight)) — new best. The work is compounding."
        }
        if isDeload {
            return "Discipline beats ego — you protected tomorrow's session."
        }
        return "\(working.count) sets, \(weightUnit.formatShort(volumeKg)) moved. Logged and learning."
    }

    // MARK: - Cost line

    /// A recovery estimate from the slowest muscle group trained today. Honest
    /// and cheap — no strain model invented; just the engine's base recovery
    /// hours for the groups that actually did work.
    private static func costLine(workout: Workout) -> String? {
        let groups = Set(workout.exercises.compactMap(\.category))
            .filter { $0 != .cardio && $0 != .other }
        guard !groups.isEmpty else { return nil }
        let hours = groups
            .map { RecoveryEngine.baseRecoveryHours[$0] ?? 48 }
            .max() ?? 48
        return "Full recovery in ~\(Int(hours.rounded()))h"
    }

    // MARK: - Tomorrow line

    private static func tomorrowLine(settings: UserSettings) -> String {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: .now) ?? .now
        let weekday = cal.component(.weekday, from: tomorrow)
        if let name = settings.weeklyPlan[weekday], !name.isEmpty {
            return "Tomorrow: \(name) — final call after your morning signals"
        }
        return "Tomorrow: open — the plan sets once your morning signals are in"
    }
}
