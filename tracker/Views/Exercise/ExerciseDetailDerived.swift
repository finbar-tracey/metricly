import SwiftUI
import SwiftData

extension ExerciseDetailView {

    var lastSessionSummaryText: String? {
        guard let last = previousSession else { return nil }
        let working = last.sets.filter { !$0.isWarmUp && $0.weight > 0 }
        guard let top = working.max(by: { $0.weight < $1.weight }) else { return nil }
        let count = working.count
        return "Last: \(count) × \(top.reps) @ \(weightUnit.format(top.weight))"
    }

    var historicalBestWeight: Double {
        allExercises
            .filter { other in
                other.name == exercise.name
                && other.persistentModelID != exercise.persistentModelID
                && !(other.workout?.isTemplate ?? true)
            }
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .map(\.weight)
            .max() ?? 0
    }

    var suggestedSet: SuggestedSet? {
        guard !isCardioExercise else { return nil }
        let history = allExercises.filter { $0.name == exercise.name }
        return SuggestedSetEngine.suggestNextSet(for: exercise, history: history)
    }

    var restMenuLabel: String {
        if let secs = exercise.customRestDuration {
            return "Rest: \(secs)s (custom)"
        }
        let global = settingsArray.first?.defaultRestDuration ?? 90
        return "Rest: \(global)s (default)"
    }

    var previousSession: Exercise? {
        allExercises
            .filter { other in
                other.name == exercise.name
                && other.persistentModelID != exercise.persistentModelID
                && !(other.workout?.isTemplate ?? true)
                && !other.sets.isEmpty
            }
            .sorted { a, b in
                (a.workout?.date ?? .distantPast) > (b.workout?.date ?? .distantPast)
            }
            .first
    }

    var isCardioExercise: Bool {
        exercise.category == .cardio
    }

    var exercisePlanHint: ExercisePlanHintView? {
        guard let cat = exercise.category,
              let plan = TodayPlanStore.load(),
              !plan.alreadyTrainedToday
        else { return nil }

        if plan.avoidGroups.contains(cat) {
            return ExercisePlanHintView(
                tone: .warning,
                icon: "exclamationmark.triangle.fill",
                message: "You've trained \(cat.rawValue.lowercased()) several times this week — consider a different focus today."
            )
        }
        if plan.goEasyOnGroups.contains(cat) {
            return ExercisePlanHintView(
                tone: .caution,
                icon: "leaf.fill",
                message: "\(cat.rawValue) is still recovering — go light, leave 1–2 reps in the tank."
            )
        }
        if plan.intensity == .light {
            return ExercisePlanHintView(
                tone: .info,
                icon: "leaf.fill",
                message: "Today is a lighter session — reduce volume by ~1 set and stop short of failure."
            )
        }
        return nil
    }

    func onAppearSetup() {
        if !session.hasLoadedSettings, let settings = settingsArray.first {
            session.restTimer.restDuration = exercise.customRestDuration ?? settings.defaultRestDuration
            session.hasLoadedSettings = true
        }
        if !session.hasPreFilled {
            if let suggestion = suggestedSet {
                session.newReps = suggestion.reps
                session.newWeight = weightUnit.display(suggestion.weight)
                session.hasPreFilled = true
            } else if let lastSession = previousSession,
                      let firstSet = lastSession.sets.first {
                if firstSet.isCardio {
                    if let km = firstSet.distance {
                        session.newDistance = weightUnit.distanceUnit.display(km)
                    }
                    if let secs = firstSet.durationSeconds {
                        session.newDurationMinutes = secs / 60
                        session.newDurationSeconds = secs % 60
                    }
                } else {
                    session.newReps = firstSet.reps
                    session.newWeight = weightUnit.display(firstSet.weight)
                }
                session.hasPreFilled = true
            }
        }
    }
}
