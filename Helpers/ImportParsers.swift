import Foundation

// MARK: - Strong parser

enum StrongParser {

    static func parseRows(_ rows: [[String]]) -> [ParsedWorkout] {
        let DATE = 0, NAME = 1, EXERCISE = 2, _SET_ORDER = 3
        let WEIGHT = 4, REPS = 5, DISTANCE = 6, SECONDS = 7
        let NOTES = 8, WORKOUT_NOTES = 9, DURATION = 10
        _ = _SET_ORDER

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

            if bucket.exercises[exerciseName] == nil {
                bucket.exerciseOrder.append(exerciseName)
                bucket.exercises[exerciseName] = ParsedExercise(
                    name: exerciseName,
                    supersetGroup: nil,
                    notes: "",
                    sets: []
                )
            }

            guard let reps = Int(row[REPS].trimmingCharacters(in: .whitespaces)),
                  reps > 0
            else { continue }
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
                distanceKm: distance,
                durationSeconds: durationSecs
            )

            bucket.exercises[exerciseName]?.sets.append(set)
            if row.count > NOTES {
                let notes = row[NOTES].trimmingCharacters(in: .whitespaces)
                if !notes.isEmpty {
                    bucket.exercises[exerciseName]?.notes = notes
                }
            }
            byWorkout[key] = bucket
        }

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

enum HevyParser {

    static func parseRows(header: [String], rows: [[String]]) -> [ParsedWorkout] {
        let normalized = header.map {
            $0.trimmingCharacters(in: .whitespaces).lowercased()
        }
        let col = Dictionary(uniqueKeysWithValues: normalized.enumerated().map { ($1, $0) })

        guard let cTitle      = col["title"],
              let cStart      = col["start_time"],
              let cExercise   = col["exercise_title"],
              let cWeight     = col["weight_kg"],
              let cReps       = col["reps"]
        else { return [] }

        let cEnd          = col["end_time"]
        let cDescription  = col["description"]
        let cSupersetID   = col["superset_id"]
        let cExerciseNote = col["exercise_notes"]
        let cSetType      = col["set_type"]
        let cDistanceKm   = col["distance_km"]
        let cDuration     = col["duration_seconds"]
        let cRPE          = col["rpe"]

        let formatters: [DateFormatter] = {
            let candidates = [
                "d MMM yyyy, HH:mm",
                "dd MMM yyyy, HH:mm",
                "MM/dd/yyyy HH:mm",
                "yyyy-MM-dd HH:mm",
                "yyyy-MM-dd'T'HH:mm:ss",
                "yyyy-MM-dd'T'HH:mm:ssZ"
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

            let weight = ImportHelper.parseDecimal(value(row, at: cWeight)) ?? 0
            let distance: Double? = {
                guard let km = ImportHelper.parseDecimal(value(row, at: cDistanceKm)),
                      km > 0 else { return nil }
                return km   // ExerciseSet.distance is kilometres — store km, not metres
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
                distanceKm: distance,
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

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
