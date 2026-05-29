import Foundation

// MARK: - Format-agnostic intermediate representation
//
// Each per-format CSV parser produces the same `[ParsedWorkout]`
// shape; a single assembler then turns those into `Workout` /
// `Exercise` / `ExerciseSet` SwiftData rows. Decoupling parse from
// insert lets every parser stay pure (unit-testable, no
// ModelContext), and lets new formats land as a single new parser
// rather than a fresh end-to-end flow.

/// One imported workout. Date fields are wall-clock locals (no
/// timezone) because Strong and Hevy both export local times without
/// offsets. The assembler resolves them into the current calendar.
struct ParsedWorkout: Equatable {
    var title: String
    var startDate: Date
    var endDate: Date?
    var notes: String
    var exercises: [ParsedExercise]
}

struct ParsedExercise: Equatable {
    var name: String
    /// Original superset/circuit identifier from the source format
    /// (Strong's "Set Order" doesn't carry this; Hevy uses `superset_id`).
    /// `nil` means "no superset grouping" — the assembler skips assignment.
    var supersetGroup: Int?
    var notes: String
    var sets: [ParsedSet]
}

struct ParsedSet: Equatable {
    var reps: Int
    /// Always stored in kg. Per-format parsers convert from the source
    /// unit (Strong's user setting; Hevy is metric natively).
    var weightKg: Double
    /// RPE on a 1-10 scale, nil when not recorded. Strong doesn't
    /// export RPE; Hevy does (column `rpe`).
    var rpe: Int?
    var isWarmUp: Bool
    /// Distance in meters for cardio sets, nil for strength sets.
    var distanceMeters: Double?
    /// Duration in seconds for timed sets (planks, cardio), nil
    /// otherwise.
    var durationSeconds: Int?
}

// MARK: - Format detection

/// One of the supported CSV formats. New apps drop in here + a
/// matching `parse…Rows` function below; detection routes based on
/// the header row.
enum ImportFormat: Equatable {
    case metricly        // Metricly's own export
    case strong          // Strong app (iOS)
    case hevy            // Hevy app (iOS/Android)

    /// Inspect a CSV header row and return the matching format, or
    /// nil if nothing matches. Header values are compared
    /// case-insensitively after trimming whitespace; column count
    /// alone isn't enough because both Strong and Hevy use sensible
    /// English column names that overlap with Metricly's.
    static func detect(header: [String]) -> ImportFormat? {
        let normalized = Set(header.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        })

        // Hevy's signature: lowercase + underscores. The `weight_kg`
        // column is unique to Hevy among the three.
        if normalized.contains("weight_kg") &&
           normalized.contains("exercise_title") {
            return .hevy
        }

        // Strong's signature: Title Case columns. "Set Order" is
        // Strong-specific (Metricly numbers sets implicitly,
        // Hevy uses `set_index`).
        if normalized.contains("set order") &&
           normalized.contains("workout name") {
            return .strong
        }

        // Metricly's own format: positional, 10+ columns, expected
        // column names in expected positions. We don't pin the
        // exact strings here because Metricly's export evolves; the
        // existing `ImportHelper.importCSV` does a more thorough
        // structural check after this dispatch.
        if header.count >= 10,
           header[0].lowercased().contains("date"),
           header[1].lowercased().contains("workout"),
           header[8].lowercased().contains("reps"),
           header[9].lowercased().contains("weight") {
            return .metricly
        }

        return nil
    }
}

// MARK: - Strong parser
//
// Strong exports row-per-set CSVs in this column order:
//
//   Date, Workout Name, Exercise Name, Set Order, Weight, Reps,
//   Distance, Seconds, Notes, Workout Notes, Workout Duration
//
// Workout grouping: rows sharing a (Date, Workout Name) pair belong
// to the same workout. Set Order is per-exercise within a workout.
// Weight is in the user's Strong setting (kg or lb); we assume kg
// here — the UI surface that triggers the import should expose a
// unit toggle (follow-up sprint). RPE is not exported.

enum StrongParser {

    /// Convert a Strong CSV's data rows (no header) into ParsedWorkouts,
    /// preserving the source order both at the workout and exercise
    /// level. Header is the caller's responsibility (drop the first
    /// row before passing here).
    static func parseRows(_ rows: [[String]]) -> [ParsedWorkout] {
        // Strong's column order — pinned so any reshuffle on Strong's
        // side gets caught by tests rather than silently mis-mapping.
        let DATE = 0, NAME = 1, EXERCISE = 2, _SET_ORDER = 3
        let WEIGHT = 4, REPS = 5, DISTANCE = 6, SECONDS = 7
        let NOTES = 8, WORKOUT_NOTES = 9, DURATION = 10
        _ = _SET_ORDER  // silence unused-warning while keeping the named index

        struct WorkoutKey: Hashable { let date: String; let name: String }
        var workoutOrder: [WorkoutKey] = []
        var byWorkout: [WorkoutKey: (start: Date, notes: String,
                                     duration: TimeInterval?,
                                     exercises: [String: ParsedExercise],
                                     exerciseOrder: [String])] = [:]

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        for row in rows {
            // Lenient: rows with fewer columns than the minimum we care
            // about (date + name + exercise + reps + weight) get skipped.
            guard row.count > REPS else { continue }
            let dateString = row[DATE].trimmingCharacters(in: .whitespaces)
            let workoutName = row[NAME].trimmingCharacters(in: .whitespaces)
            let exerciseName = row[EXERCISE].trimmingCharacters(in: .whitespaces)
            guard !dateString.isEmpty, !workoutName.isEmpty, !exerciseName.isEmpty,
                  let parsedDate = dateFormatter.date(from: dateString)
            else { continue }

            let key = WorkoutKey(date: dateString, name: workoutName)
            if byWorkout[key] == nil {
                workoutOrder.append(key)
                // Workout-level fields are repeated on every row in
                // the export; capture from the first row we see.
                let workoutNotes = row.count > WORKOUT_NOTES
                    ? row[WORKOUT_NOTES].trimmingCharacters(in: .whitespaces)
                    : ""
                let durationSeconds: TimeInterval? = {
                    guard row.count > DURATION else { return nil }
                    let s = row[DURATION].trimmingCharacters(in: .whitespaces)
                    guard let n = Double(s), n > 0 else { return nil }
                    return n
                }()
                byWorkout[key] = (parsedDate, workoutNotes, durationSeconds, [:], [])
            }
            guard var bucket = byWorkout[key] else { continue }

            // Exercise grouping inside the workout
            if bucket.exercises[exerciseName] == nil {
                bucket.exerciseOrder.append(exerciseName)
                bucket.exercises[exerciseName] = ParsedExercise(
                    name: exerciseName,
                    supersetGroup: nil,
                    notes: "",
                    sets: []
                )
            }

            // Set row. Reps / Weight are required for a "real" set —
            // 0/0 rows happen on Strong when the user adds a placeholder
            // and never fills it in, and we filter those out.
            guard let reps = Int(row[REPS].trimmingCharacters(in: .whitespaces)),
                  reps > 0
            else { continue }
            // Strong's `Weight` column carries the raw number in the
            // user's chosen unit. Default to treating it as kg; a
            // future UI toggle can override.
            let weight = ImportHelper.parseDecimal(row[safe: WEIGHT]) ?? 0
            let distance: Double? = {
                guard row.count > DISTANCE,
                      let v = ImportHelper.parseDecimal(row[DISTANCE]),
                      v > 0 else { return nil }
                return v
            }()
            let durationSecs: Int? = {
                guard row.count > SECONDS,
                      let s = Int(row[SECONDS].trimmingCharacters(in: .whitespaces)),
                      s > 0 else { return nil }
                return s
            }()
            let set = ParsedSet(
                reps: reps,
                weightKg: weight,
                rpe: nil,
                isWarmUp: false,
                distanceMeters: distance,
                durationSeconds: durationSecs
            )

            bucket.exercises[exerciseName]?.sets.append(set)
            // Per-row exercise notes are rare in Strong but supported —
            // last-row-wins on conflicting notes.
            if row.count > NOTES {
                let notes = row[NOTES].trimmingCharacters(in: .whitespaces)
                if !notes.isEmpty {
                    bucket.exercises[exerciseName]?.notes = notes
                }
            }
            byWorkout[key] = bucket
        }

        // Materialise in original order, dropping workouts that ended
        // up with no actual sets (placeholder rows only).
        return workoutOrder.compactMap { key in
            guard let bucket = byWorkout[key] else { return nil }
            let exercises = bucket.exerciseOrder
                .compactMap { bucket.exercises[$0] }
                .filter { !$0.sets.isEmpty }
            guard !exercises.isEmpty else { return nil }
            let endDate: Date? = bucket.duration.map {
                bucket.start.addingTimeInterval($0)
            }
            return ParsedWorkout(
                title: key.name,
                startDate: bucket.start,
                endDate: endDate,
                notes: bucket.notes,
                exercises: exercises
            )
        }
    }
}

// MARK: - Hevy parser
//
// Hevy exports row-per-set CSVs with these columns (lowercase,
// underscore-separated):
//
//   title, start_time, end_time, description, exercise_title,
//   superset_id, exercise_notes, set_index, set_type, weight_kg,
//   reps, distance_km, duration_seconds, rpe
//
// Workout grouping: rows sharing (title, start_time) belong to the
// same workout. Weight is always metric (`weight_kg`); distance is
// always metric (`distance_km`). `set_type` is one of "warmup" /
// "normal" / "failure" / "dropset" — the first becomes
// `isWarmUp: true`, the rest become working sets.

enum HevyParser {

    /// Same contract as `StrongParser.parseRows` — rows are the data
    /// rows (header dropped). Column lookup is by header name rather
    /// than positional because Hevy has occasionally added columns at
    /// the end and we don't want a downstream parser to break on it.
    static func parseRows(header: [String], rows: [[String]]) -> [ParsedWorkout] {
        // Build a name → index map so column adds / reorders on
        // Hevy's side don't shift indexing.
        let normalized = header.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        let col = Dictionary(uniqueKeysWithValues: normalized.enumerated().map { ($1, $0) })

        // Required columns — bail (return empty) if any are missing.
        guard let cTitle      = col["title"],
              let cStart      = col["start_time"],
              let cExercise   = col["exercise_title"],
              let cWeight     = col["weight_kg"],
              let cReps       = col["reps"]
        else { return [] }
        // Optional columns
        let cEnd          = col["end_time"]
        let cDescription  = col["description"]
        let cSupersetID   = col["superset_id"]
        let cExerciseNote = col["exercise_notes"]
        let cSetType      = col["set_type"]
        let cDistanceKm   = col["distance_km"]
        let cDuration     = col["duration_seconds"]
        let cRPE          = col["rpe"]

        // Hevy timestamps come in two common shapes depending on the
        // exporting locale: "15 Jan 2024, 06:30" (UK-ish) and
        // "01/15/2024 06:30" (US-ish). Try the formats in order.
        let formatters: [DateFormatter] = {
            let candidates = [
                "d MMM yyyy, HH:mm",
                "dd MMM yyyy, HH:mm",
                "MM/dd/yyyy HH:mm",
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd'T'HH:mm:ss",   // ISO without offset
                "yyyy-MM-dd'T'HH:mm:ssZ"   // ISO with offset
            ]
            return candidates.map {
                let f = DateFormatter()
                f.dateFormat = $0
                f.locale = Locale(identifier: "en_US_POSIX")
                return f
            }
        }()
        func parseDate(_ raw: String) -> Date? {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            for f in formatters {
                if let d = f.date(from: trimmed) { return d }
            }
            return nil
        }

        struct WorkoutKey: Hashable { let title: String; let start: String }
        var workoutOrder: [WorkoutKey] = []
        var byWorkout: [WorkoutKey: (start: Date, end: Date?, notes: String,
                                     exercises: [String: ParsedExercise],
                                     exerciseOrder: [String])] = [:]

        func value(_ row: [String], at index: Int?) -> String? {
            guard let i = index, row.indices.contains(i) else { return nil }
            return row[i].trimmingCharacters(in: .whitespaces)
        }

        for row in rows {
            // Required fields
            guard let title = value(row, at: cTitle), !title.isEmpty,
                  let startStr = value(row, at: cStart), !startStr.isEmpty,
                  let exerciseName = value(row, at: cExercise), !exerciseName.isEmpty,
                  let startDate = parseDate(startStr),
                  let repsStr = value(row, at: cReps), let reps = Int(repsStr), reps > 0
            else { continue }

            let key = WorkoutKey(title: title, start: startStr)
            if byWorkout[key] == nil {
                workoutOrder.append(key)
                let endDate: Date? = value(row, at: cEnd).flatMap(parseDate)
                let notes = value(row, at: cDescription) ?? ""
                byWorkout[key] = (startDate, endDate, notes, [:], [])
            }
            guard var bucket = byWorkout[key] else { continue }

            if bucket.exercises[exerciseName] == nil {
                bucket.exerciseOrder.append(exerciseName)
                let superset = value(row, at: cSupersetID).flatMap { Int($0) }
                let exerciseNotes = value(row, at: cExerciseNote) ?? ""
                bucket.exercises[exerciseName] = ParsedExercise(
                    name: exerciseName,
                    supersetGroup: superset,
                    notes: exerciseNotes,
                    sets: []
                )
            }

            // weight_kg / distance_km are metric per Hevy's spec.
            let weight = ImportHelper.parseDecimal(value(row, at: cWeight)) ?? 0
            let distance: Double? = {
                guard let km = ImportHelper.parseDecimal(value(row, at: cDistanceKm)),
                      km > 0 else { return nil }
                return km * 1000   // convert to meters for our schema
            }()
            let duration: Int? = {
                guard let s = value(row, at: cDuration),
                      let n = Int(s), n > 0 else { return nil }
                return n
            }()
            let rpe: Int? = {
                guard let r = value(row, at: cRPE),
                      let n = Int(r), (1...10).contains(n) else { return nil }
                return n
            }()
            let setType = value(row, at: cSetType)?.lowercased() ?? "normal"
            let isWarmUp = setType == "warmup"

            let set = ParsedSet(
                reps: reps,
                weightKg: weight,
                rpe: rpe,
                isWarmUp: isWarmUp,
                distanceMeters: distance,
                durationSeconds: duration
            )
            bucket.exercises[exerciseName]?.sets.append(set)
            byWorkout[key] = bucket
        }

        return workoutOrder.compactMap { key in
            guard let bucket = byWorkout[key] else { return nil }
            let exercises = bucket.exerciseOrder
                .compactMap { bucket.exercises[$0] }
                .filter { !$0.sets.isEmpty }
            guard !exercises.isEmpty else { return nil }
            return ParsedWorkout(
                title: key.title,
                startDate: bucket.start,
                endDate: bucket.end,
                notes: bucket.notes,
                exercises: exercises
            )
        }
    }
}

// MARK: - safe-subscript shim (mirrors the one in ImportHelper.swift)

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
