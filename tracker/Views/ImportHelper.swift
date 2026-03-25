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
                          let weight = Double(row[safe: 9] ?? "")
                    else { continue }

                    let set = ExerciseSet(reps: reps, weight: weight, exercise: exercise)
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

    private static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        for char in text {
            if inQuotes {
                if char == "\"" {
                    // Check for escaped quote
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
                case "\r":
                    break // skip carriage returns
                default:
                    currentField.append(char)
                }
            }
        }

        // Handle last row
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.isEmpty }) {
                rows.append(currentRow)
            }
        }

        return rows
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
