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

        // Validate header
        let header = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        guard header.count >= 10,
              header[0].contains("date"),
              header[1].contains("workout"),
              header[8].contains("reps"),
              header[9].contains("weight")
        else {
            throw ImportError.invalidFormat
        }

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
