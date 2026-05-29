import Foundation
import SwiftData

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case legs = "Legs"
    case core = "Core"
    case cardio = "Cardio"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .chest: return "figure.strengthtraining.traditional"
        case .back: return "figure.rower"
        case .shoulders: return "figure.boxing"
        case .biceps: return "figure.curling"
        case .triceps: return "figure.highintensity.intervaltraining"
        case .legs: return "figure.step.training"
        case .core: return "figure.core.training"
        case .cardio: return "figure.run"
        case .other: return "dumbbell"
        }
    }

    /// Best-guess muscle group from an exercise name. Used by the
    /// Strong/Hevy importers when the source format doesn't carry an
    /// explicit category — better than dropping every imported
    /// exercise into `.other` (which would zero out recovery math
    /// for the user's actual training).
    ///
    /// Matches case-insensitively against name fragments. The order
    /// of the switches matters: more specific matches must come
    /// before broader ones (e.g. "tricep pushdown" before "push" to
    /// avoid bucketing arm work into chest). When no fragment
    /// matches, returns `nil` and the caller can default to `.other`.
    static func inferred(fromName name: String) -> MuscleGroup? {
        let n = name.lowercased()

        // Cardio first. NOTE: bare substrings like "run" or "row" trip
        // false positives on "crunch" and "rowing" (which IS cardio,
        // but the same logic catches "row" inside "bench row" which
        // really is the back row exercise, NOT cardio). Use leading-
        // space or explicit-word matching so "Crunch" doesn't fall
        // into cardio via the embedded "run" substring.
        let cardioWords = ["running", "jogging", "treadmill",
                           "outdoor run", "indoor run", "trail run",
                           "outdoor walk", "indoor walk",
                           "hiking", "swimming",
                           "cycling", "outdoor cycle", "indoor cycle",
                           "biking", "elliptical", "rowing machine",
                           "stair master", "stairmaster", "stair climber",
                           "stair stepper"]
        if cardioWords.contains(where: { n.contains($0) }) {
            return .cardio
        }
        // Single-word cardio names that need word-boundary matching to
        // avoid colliding with substrings inside strength lifts.
        let cardioTokens = ["run", "jog", "walk", "ride", "hike",
                            "swim", "bike", "cycle"]
        let tokens = n.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map(String.init)
        if cardioTokens.contains(where: { token in tokens.contains(token) }) {
            return .cardio
        }

        // Arms — check biceps/triceps before back/chest so "tricep
        // extension" doesn't fall into the broader category.
        if n.contains("curl") && !n.contains("leg curl") && !n.contains("hamstring") {
            return .biceps
        }
        if n.contains("tricep") || n.contains("pushdown") || n.contains("skullcrusher")
            || n.contains("kickback") || n.contains("dip") {
            return .triceps
        }
        if n.contains("bicep") || n.contains("hammer") || n.contains("preacher")
            || n.contains("chin-up") || n.contains("chinup") {
            return .biceps
        }

        // Shoulders — also "overhead press" / "OHP" / "lateral".
        if n.contains("shoulder") || n.contains("ohp") || n.contains("military")
            || n.contains("overhead press") || n.contains("lateral")
            || n.contains("rear delt") || n.contains("front raise")
            || n.contains("upright row") || n.contains("face pull")
            || n.contains("arnold") {
            return .shoulders
        }

        // Legs — squat, deadlift, leg, calf, glute, lunge, hip thrust.
        if n.contains("squat") || n.contains("deadlift") || n.contains("leg")
            || n.contains("calf") || n.contains("glute") || n.contains("lunge")
            || n.contains("hip thrust") || n.contains("hamstring") || n.contains("quad")
            || n.contains("rdl") || n.contains("romanian")
            || n.contains("step up") || n.contains("step-up")
            || n.contains("split squat") {
            return .legs
        }

        // Core / abs.
        if n.contains("abs") || n.contains("plank") || n.contains("crunch")
            || n.contains("sit-up") || n.contains("situp") || n.contains("sit up")
            || n.contains("oblique") || n.contains("ab wheel") || n.contains("hanging")
            || n.contains("toes to bar") || n.contains("hollow")
            || n.contains("core") {
            return .core
        }

        // Back — pull, row, lat, deadlift (already caught above), shrug.
        if n.contains("pull-up") || n.contains("pullup") || n.contains("pull up")
            || n.contains("row") || n.contains("lat ")
            || n.contains("lat pull") || n.contains("pulldown")
            || n.contains("shrug") {
            return .back
        }

        // Chest — bench, fly, push-up.
        if n.contains("bench") || n.contains("press") && (n.contains("chest")
                                                          || n.contains("incline")
                                                          || n.contains("decline"))
            || n.contains("fly") || n.contains("flye")
            || n.contains("push-up") || n.contains("pushup") || n.contains("push up")
            || n.contains("chest") {
            return .chest
        }

        // Fallback: bare "press" → shoulders, since that's the most
        // common ambiguous case. Anything else: unknown.
        if n.contains("press") {
            return .shoulders
        }
        return nil
    }
}

@Model
final class Exercise {
    var name: String = ""
    var notes: String = ""
    var order: Int = 0
    var supersetGroup: Int? = nil
    var categoryRaw: String? = nil
    var customRestDuration: Int? = nil
    var workout: Workout?
    @Relationship(deleteRule: .cascade, inverse: \ExerciseSet.exercise)
    var _sets: [ExerciseSet]? = nil

    /// Non-optional accessor — CloudKit requires the stored relationship be optional.
    var sets: [ExerciseSet] {
        get { _sets ?? [] }
        set { _sets = newValue }
    }

    var category: MuscleGroup? {
        get { categoryRaw.flatMap { MuscleGroup(rawValue: $0) } }
        set { categoryRaw = newValue?.rawValue }
    }

    init(name: String, workout: Workout? = nil, category: MuscleGroup? = nil) {
        self.name = name
        self.notes = ""
        self.order = 0
        self.supersetGroup = nil
        self.categoryRaw = category?.rawValue
        self.workout = workout
        self.sets = []
    }
}
