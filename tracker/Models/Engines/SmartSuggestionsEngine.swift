import Foundation
import SwiftData

struct SuggestedExercise: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let group: MuscleGroup
    let reason: String
}

enum SmartSuggestionsEngine {

    static func muscleReadiness(from recovery: RecoveryResult) -> [(MuscleGroup, Double)] {
        recovery.muscleResults.map { ($0.group, $0.freshness) }.sorted { $0.1 > $1.1 }
    }

    static func readyMuscles(from recovery: RecoveryResult) -> [MuscleGroup] {
        recovery.muscleResults.filter { $0.freshness >= 0.7 }.map(\.group)
    }

    static func suggestedExercises(
        recovery: RecoveryResult,
        workouts: [Workout]
    ) -> [SuggestedExercise] {
        let ready = readyMuscles(from: recovery)
        let recent = recentExerciseNames(days: 7, in: workouts)
        var suggestions: [SuggestedExercise] = []
        for group in ready.prefix(4) {
            let exercises = exercisesForGroup(group, workouts: workouts)
            let fresh = exercises.filter { !recent.contains($0.lowercased()) }
            let pick = fresh.first ?? exercises.first ?? group.rawValue
            suggestions.append(
                SuggestedExercise(
                    name: pick,
                    group: group,
                    reason: reasonForGroup(group, recovery: recovery)
                )
            )
        }
        return suggestions
    }

    static func recentExerciseNames(days: Int, in workouts: [Workout]) -> Set<String> {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: .now) ?? .now
        return Set(
            workouts
                .filter { $0.date >= cutoff }
                .flatMap { $0.exercises.map { $0.name.lowercased() } }
        )
    }

    static func reasonForGroup(_ group: MuscleGroup, recovery: RecoveryResult) -> String {
        if let lastTrained = recovery.muscleResults.first(where: { $0.group == group })?.lastTrained {
            let days = Int(Date.now.timeIntervalSince(lastTrained) / 86400)
            if days == 0 { return "Trained today" }
            if days == 1 { return "Last trained yesterday" }
            return "Last trained \(days) days ago"
        }
        return "Not recently trained"
    }

    static func exercisesForGroup(_ group: MuscleGroup, workouts: [Workout]) -> [String] {
        let used = workouts.flatMap(\.exercises).filter { $0.category == group }.map(\.name)
        let unique = Array(Set(used))
        if !unique.isEmpty { return unique }
        switch group {
        case .chest: return ["Bench Press", "Dumbbell Fly", "Incline Press"]
        case .back: return ["Barbell Row", "Lat Pulldown", "Dumbbell Row"]
        case .shoulders: return ["Overhead Press", "Lateral Raise", "Face Pull"]
        case .biceps: return ["Barbell Curl", "Hammer Curl", "Preacher Curl"]
        case .triceps: return ["Tricep Pushdown", "Overhead Extension", "Skull Crusher"]
        case .legs: return ["Squat", "Romanian Deadlift", "Leg Press"]
        case .core: return ["Plank", "Cable Crunch", "Hanging Leg Raise"]
        case .cardio: return ["Running", "Cycling", "Rowing"]
        case .other: return ["Deadlift", "Farmer Walk"]
        }
    }
}
