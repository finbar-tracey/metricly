import Foundation
import SwiftData
import UniformTypeIdentifiers

struct ImportHelper {
    enum ImportError: LocalizedError {
        case invalidFormat
        case noData
        case parseError(String)

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "The CSV file format is not recognized."
            case .noData: return "The CSV file contains no workout data."
            case .parseError(let detail): return "Parse error: \(detail)"
            }
        }
    }

    /// A pre-parse preview of a Strong/Hevy CSV used by the Settings
    /// flow to show the user a "We found N workouts, K exercises"
    /// confirmation sheet before committing. Metricly's own format
    /// imports directly (no preview) because users importing their
    /// own export already know what's in it.
    struct ImportPreview: Identifiable {
        /// SwiftUI's `sheet(item:)` needs Identifiable. The id is a
        /// stable per-instance UUID — uniqueness is per-sheet-
        /// presentation, not per-content, so a fresh UUID per init
        /// is correct.
        let id = UUID()
        let format: ImportFormat
        let workouts: [ParsedWorkout]

        var workoutCount: Int { workouts.count }
        var exerciseCount: Int {
            Set(workouts.flatMap { $0.exercises.map { $0.name.lowercased() } }).count
        }
        var totalSetCount: Int {
            workouts.reduce(0) { $0 + $1.exercises.reduce(0) { $0 + $1.sets.count } }
        }
        /// Earliest workout date in the file, for "history since…" copy.
        var earliestDate: Date? {
            workouts.map(\.startDate).min()
        }
        var sampleWorkout: ParsedWorkout? { workouts.first }
    }

    /// One of:
    ///  - `.preview(ImportPreview)` — Strong/Hevy file, caller should
    ///     show a confirmation sheet and call
    ///     `commitPreview(_:into:)` on user confirm.
    ///  - `.metriclyDirect(rowsToImport: Int)` — Metricly's own
    ///     format; the import is fast and the user already knows
    ///     what's in their own export, so commit directly with the
    ///     existing path.
    ///  - throws `ImportError` for unknown/empty/malformed input.
    enum ImportPlan {
        case preview(ImportPreview)
        case metriclyDirect      // caller falls through to importCSV
    }

    /// Inspect a CSV at `url` and decide how to import it. Pure
    /// (no model-context side effects) so the Settings UI can decide
    /// what to present before committing.
    static func plan(from url: URL) throws -> ImportPlan {
        let content = try readContents(of: url)
        let rows = parseCSVRows(content)
        guard rows.count > 1 else { throw ImportError.noData }
        let header = rows[0]
        let dataRows = Array(rows.dropFirst())

        switch ImportFormat.detect(header: header) {
        case .strong:
            let workouts = StrongParser.parseRows(dataRows)
            guard !workouts.isEmpty else { throw ImportError.noData }
            return .preview(ImportPreview(format: .strong, workouts: workouts))

        case .hevy:
            let workouts = HevyParser.parseRows(header: header, rows: dataRows)
            guard !workouts.isEmpty else { throw ImportError.noData }
            return .preview(ImportPreview(format: .hevy, workouts: workouts))

        case .metricly:
            return .metriclyDirect

        case .none:
            throw ImportError.invalidFormat
        }
    }

    /// Commit a previously-planned `ImportPreview` into a context.
    /// Returns the number of workouts inserted.
    @discardableResult
    static func commitPreview(_ preview: ImportPreview,
                              into context: ModelContext) -> Int {
        insertParsedWorkouts(preview.workouts, into: context)
    }

    /// Shared file-read with security-scoped-resource handling. Used
    /// by both the preview-plan path and the direct-import path so
    /// they can't drift on how they reach the user's chosen file.
    private static func readContents(of url: URL) throws -> String {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            return try String(contentsOf: url, encoding: .utf8)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    static func importCSV(from url: URL, into context: ModelContext) throws -> Int {
        let content: String
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            content = try String(contentsOf: url, encoding: .utf8)
        } else {
            content = try String(contentsOf: url, encoding: .utf8)
        }

        let rows = parseCSVRows(content)
        guard rows.count > 1 else { throw ImportError.noData }
        let headerRow = rows[0]
        let dataRows = Array(rows.dropFirst())

        // Detect format and dispatch. Metricly's own import keeps its
        // rich inline parser (it preserves Metricly-specific fields
        // like the per-workout rating and the explicit muscle-group
        // category that Strong/Hevy don't export). Strong and Hevy go
        // through the structured parsers in `ImportFormats.swift` and
        // share a common `insertParsedWorkouts` assembler.
        switch ImportFormat.detect(header: headerRow) {
        case .strong:
            let parsed = StrongParser.parseRows(dataRows)
            guard !parsed.isEmpty else { throw ImportError.noData }
            return insertParsedWorkouts(parsed, into: context)

        case .hevy:
            let parsed = HevyParser.parseRows(header: headerRow, rows: dataRows)
            guard !parsed.isEmpty else { throw ImportError.noData }
            return insertParsedWorkouts(parsed, into: context)

        case .metricly:
            // fall through to the existing inline Metricly path below.
            break

        case .none:
            throw ImportError.invalidFormat
        }

        // Metricly's own format from here on — the original inline
        // parser, preserved verbatim so Metricly-side fields
        // (per-workout rating, explicit category, superset group ID)
        // continue to round-trip correctly.
        let header = headerRow.map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        // (Header check already happened in detect(); we keep the
        // local `header` lowercase alias for the existing positional
        // code below.)
        _ = header

        // Group rows by workout (date + name combo)
        struct WorkoutKey: Hashable {
            let date: String
            let name: String
        }

        var workoutGroups: [WorkoutKey: [[String]]] = [:]
        var orderedKeys: [WorkoutKey] = []

        for row in rows.dropFirst() {
            guard row.count >= 10 else { continue }
            let key = WorkoutKey(date: row[0], name: row[1])
            if workoutGroups[key] == nil {
                orderedKeys.append(key)
            }
            workoutGroups[key, default: []].append(row)
        }

        guard !orderedKeys.isEmpty else { throw ImportError.noData }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var importedCount = 0

        for key in orderedKeys {
            guard let rows = workoutGroups[key] else { continue }
            let date = dateFormatter.date(from: key.date) ?? .now
            let workout = Workout(name: key.name, date: date)

            // Rating from first row
            if let ratingStr = rows.first?[safe: 2], let rating = Int(ratingStr), rating > 0 {
                workout.rating = rating
            }

            // Duration from first row
            if let durationStr = rows.first?[safe: 3], let durationMin = Int(durationStr), durationMin > 0 {
                workout.startTime = date
                workout.endTime = date.addingTimeInterval(TimeInterval(durationMin * 60))
            }

            context.insert(workout)

            // Group rows by exercise name (preserving order)
            struct ExerciseKey: Hashable {
                let name: String
                let order: Int
            }
            var exerciseGroups: [String: [[String]]] = [:]
            var exerciseOrder: [String] = []

            for row in rows {
                let exerciseName = row[4]
                if exerciseGroups[exerciseName] == nil {
                    exerciseOrder.append(exerciseName)
                }
                exerciseGroups[exerciseName, default: []].append(row)
            }

            for (order, exerciseName) in exerciseOrder.enumerated() {
                guard let setRows = exerciseGroups[exerciseName] else { continue }
                let categoryStr = setRows.first?[safe: 5] ?? ""
                let category = MuscleGroup.allCases.first { $0.rawValue == categoryStr }
                let exercise = Exercise(name: exerciseName, workout: workout, category: category)
                exercise.order = order

                // Superset group from first row
                if let ssStr = setRows.first?[safe: 6], let ss = Int(ssStr) {
                    exercise.supersetGroup = ss
                }

                context.insert(exercise)
                workout.exercises.append(exercise)

                for row in setRows {
                    guard let reps = Int(row[safe: 8] ?? ""),
                          let weight = parseDecimal(row[safe: 9])
                    else { continue }

                    let rpe: Int? = if let rpeStr = row[safe: 10], let val = Int(rpeStr), (1...10).contains(val) { val } else { nil }
                    let dist: Double? = if let val = parseDecimal(row[safe: 11]), val > 0 { val } else { nil }
                    let durSecs: Int? = if let durStr = row[safe: 12], let val = Int(durStr), val > 0 { val } else { nil }
                    let set = ExerciseSet(reps: reps, weight: weight, rpe: rpe, distance: dist, durationSeconds: durSecs, exercise: exercise)
                    context.insert(set)
                    exercise.sets.append(set)
                }
            }

            importedCount += 1
        }

        try context.save()
        return importedCount
    }

    // MARK: - Assembler for Strong / Hevy ParsedWorkouts

    /// Turn a `[ParsedWorkout]` (produced by `StrongParser` or
    /// `HevyParser`) into SwiftData rows on `context`. Returns the
    /// number of workouts inserted.
    ///
    /// Category inference: the parsed shape doesn't carry a muscle
    /// group, so we infer one from the exercise name via
    /// `MuscleGroup.inferred(fromName:)` (matches the same heuristic
    /// the live workout flow uses for new exercises). Categories
    /// without a confident match land as `.other` — better than
    /// guessing and corrupting recovery math.
    static func insertParsedWorkouts(_ workouts: [ParsedWorkout],
                                     into context: ModelContext) -> Int {
        var imported = 0
        for parsed in workouts {
            let workout = Workout(name: parsed.title, date: parsed.startDate)
            workout.notes = parsed.notes
            workout.startTime = parsed.startDate
            workout.endTime = parsed.endDate
            context.insert(workout)

            for (order, parsedEx) in parsed.exercises.enumerated() {
                let category = MuscleGroup.inferred(fromName: parsedEx.name)
                let exercise = Exercise(
                    name: parsedEx.name,
                    workout: workout,
                    category: category
                )
                exercise.order = order
                exercise.notes = parsedEx.notes
                if let supersetGroup = parsedEx.supersetGroup {
                    exercise.supersetGroup = supersetGroup
                }
                context.insert(exercise)
                workout.exercises.append(exercise)

                for parsedSet in parsedEx.sets {
                    let set = ExerciseSet(
                        reps: parsedSet.reps,
                        weight: parsedSet.weightKg,
                        isWarmUp: parsedSet.isWarmUp,
                        rpe: parsedSet.rpe,
                        distance: parsedSet.distanceMeters,
                        durationSeconds: parsedSet.durationSeconds,
                        exercise: exercise
                    )
                    context.insert(set)
                    exercise.sets.append(set)
                }
            }
            imported += 1
        }
        try? context.save()
        return imported
    }

    // MARK: - CSV Parsing

    /// RFC 4180-style CSV parser. Handles:
    /// - Quoted fields containing commas, quotes, and newlines
    /// - Doubled-quote escape inside quoted fields (`""` → `"`)
    /// - Mixed line endings (LF, CRLF) — bare CR characters are stripped
    static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        // Normalise line endings before iterating. Swift treats "\r\n" as a single
        // grapheme cluster, so neither the "\r" nor "\n" case below would match
        // CRLF input. Collapse to "\n" upfront, then strip any lone CRs.
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let chars = Array(normalized)
        var i = 0
        while i < chars.count {
            let char = chars[i]

            if inQuotes {
                if char == "\"" {
                    // Doubled-quote escape: emit one quote, stay in quotes
                    if i + 1 < chars.count && chars[i + 1] == "\"" {
                        currentField.append("\"")
                        i += 2
                        continue
                    }
                    // Otherwise it's a closing quote
                    inQuotes = false
                } else {
                    currentField.append(char)
                }
            } else {
                switch char {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    currentField = ""
                    if !currentRow.allSatisfy({ $0.isEmpty }) {
                        rows.append(currentRow)
                    }
                    currentRow = []
                default:
                    currentField.append(char)
                }
            }
            i += 1
        }

        // Handle last row (no trailing newline)
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }

    // MARK: - Locale-tolerant decimal parsing

    /// Parses a decimal string accepting both period (`80.5`) and comma
    /// (`80,5`) decimal separators. The app's own exports always use
    /// period — this exists for CSVs that round-trip through external
    /// tools (e.g. a German Excel) where the decimal mark gets swapped.
    ///
    /// Doesn't try to handle thousands separators — `1,234.5` and
    /// `1.234,5` both return nil because they're ambiguous and we'd
    /// rather drop the row than silently misread it as 1234.5 or 1.234.
    static func parseDecimal(_ s: String?) -> Double? {
        guard let s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if let v = Double(s) { return v }
        // Only attempt the comma swap when there's exactly one comma and
        // no period — the typical European single-decimal case. Anything
        // more ambiguous than that falls through to nil.
        let commaCount = s.filter { $0 == "," }.count
        let hasPeriod  = s.contains(".")
        if commaCount == 1 && !hasPeriod {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
