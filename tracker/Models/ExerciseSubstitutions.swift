import Foundation

/// Curated library of "if this muscle group is fatigued, swap that
/// movement for this less-fatiguing alternative" pairs.
///
/// **Why curated rather than learned.** A learned substitution
/// system (cluster exercises by movement pattern, pick the nearest
/// less-loaded sibling) needs a body of training data per user to
/// be useful, and new users have none. A hand-picked library lands
/// useful suggestions on day one and degrades gracefully — unknown
/// exercises return no substitutions rather than producing nonsense
/// pairs. A future learned layer can sit on top of this without
/// replacing it.
///
/// **Selection criteria for each swap.** Each suggestion is meant
/// to hit roughly the same target muscle but with less systemic
/// fatigue cost — typically by:
///   - moving from free weight to machine (eliminates stabiliser
///     load)
///   - moving from a heavy compound to an isolation (reduces
///     systemic CNS demand)
///   - reducing leverage demands on the lower back (rows from a
///     supported position, hinges with less spinal compression)
///
/// **Adding to the library.** Keep keys lowercased; use a single
/// canonical exercise name per key (matchers handle minor variants
/// like "Bench Press" / "Barbell Bench"). Suggestions are listed
/// in preference order — first that survives "user isn't already
/// doing this" filter wins.
enum ExerciseSubstitutions {

    /// The raw library. Key = canonical lowercased exercise name.
    /// Value = ordered list of less-fatiguing alternatives. Exposed
    /// internal-static so tests can pin the contents without making
    /// the storage public.
    static let library: [String: [String]] = [

        // MARK: Chest
        "bench press":          ["Machine Chest Press", "Push-up", "Cable Fly"],
        "barbell bench press":  ["Machine Chest Press", "Push-up", "Cable Fly"],
        "incline bench press":  ["Incline Machine Press", "Incline Dumbbell Fly", "Push-up"],
        "decline bench press":  ["Decline Machine Press", "Cable Fly", "Push-up"],
        "dumbbell press":       ["Machine Chest Press", "Push-up", "Cable Fly"],

        // MARK: Back — the row family. Chest-supported variants take
        // load off the lower back, which is the usual reason for
        // suggesting a swap mid-week.
        "barbell row":          ["Chest-Supported Row", "Cable Row", "Machine Row"],
        "bent over row":        ["Chest-Supported Row", "Cable Row", "Machine Row"],
        "pendlay row":          ["Chest-Supported Row", "Cable Row", "Machine Row"],
        "deadlift":             ["Romanian Deadlift", "Hip Thrust", "Trap Bar Deadlift"],
        "romanian deadlift":    ["Seated Leg Curl", "Hip Thrust", "Glute Bridge"],
        "pull-up":              ["Lat Pulldown", "Assisted Pull-up", "Cable Pullover"],

        // MARK: Legs — squat variants swap to machines or unilateral
        // work that reduce axial load.
        "squat":                ["Hack Squat", "Leg Press", "Bulgarian Split Squat"],
        "barbell squat":        ["Hack Squat", "Leg Press", "Bulgarian Split Squat"],
        "front squat":          ["Hack Squat", "Leg Press", "Goblet Squat"],
        "back squat":           ["Hack Squat", "Leg Press", "Bulgarian Split Squat"],
        "lunge":                ["Bulgarian Split Squat", "Step-up", "Leg Press"],

        // MARK: Shoulders — overhead pressing is the big systemic
        // load; lateral / rear delt work covers most of what the
        // user would lose.
        "overhead press":       ["Seated Machine Press", "Lateral Raise", "Cable Lateral Raise"],
        "military press":       ["Seated Machine Press", "Lateral Raise", "Cable Lateral Raise"],
        "ohp":                  ["Seated Machine Press", "Lateral Raise", "Cable Lateral Raise"],
        "push press":           ["Seated Machine Press", "Lateral Raise", "Front Raise"],

        // MARK: Arms — keep simple. Curls and pushdowns are already
        // pretty low-systemic; the swap is more about variety than
        // fatigue management.
        "bicep curl":           ["Hammer Curl", "Cable Curl", "Preacher Curl"],
        "barbell curl":         ["Hammer Curl", "Cable Curl", "Preacher Curl"],
        "tricep pushdown":      ["Cable Overhead Extension", "Close-Grip Push-up", "Skullcrusher"],
    ]

    /// Suggest a substitution for the given exercise name, optionally
    /// avoiding exercises the user already has in this workout. Returns
    /// nil when no library entry matches OR when every candidate is
    /// already in the workout (we never recommend "swap to something
    /// you're already doing").
    ///
    /// - Parameters:
    ///   - exerciseName: The original exercise name. Matched
    ///     case-insensitively after trimming whitespace.
    ///   - alreadyInWorkout: Other exercise names already in the
    ///     workout. Substitutions matching any of these
    ///     (case-insensitive) are skipped.
    static func suggestion(
        for exerciseName: String,
        alreadyInWorkout: [String] = []
    ) -> String? {
        let key = exerciseName
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        guard let candidates = library[key], !candidates.isEmpty else {
            return nil
        }
        let alreadyLowered = Set(alreadyInWorkout.map { $0.lowercased() })
        return candidates.first { candidate in
            !alreadyLowered.contains(candidate.lowercased())
        }
    }

    /// True when the library has at least one substitution for the
    /// given exercise name. Exposed for cheap pre-flight checks —
    /// `suggestion(for:)` is more expensive when many exercises are
    /// up for substitution at once.
    static func hasSubstitution(for exerciseName: String) -> Bool {
        let key = exerciseName
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
        return library[key] != nil
    }
}
