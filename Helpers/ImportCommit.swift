import Foundation
import SwiftData

// MARK: - SwiftData commit (Strong / Hevy / Metricly)

extension ImportHelper {

    @discardableResult
    static func commitPreview(_ preview: ImportPreview,
                              into context: ModelContext) -> Int {
        insertParsedWorkouts(preview.workouts, into: context)
    }

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

    /// Metricly's own export format — preserves rating, category, superset fields.
    @discardableResult
    static func importMetriclyRows(_ rows: [[String]], into context: ModelContext) throws -> Int {
        guard rows.count > 1 else { throw ImportError.noData }

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

            if let ratingStr = rows.first?[safe: 2], let rating = Int(ratingStr), rating > 0 {
                workout.rating = rating
            }

            if let durationStr = rows.first?[safe: 3], let durationMin = Int(durationStr), durationMin > 0 {
                workout.startTime = date
                workout.endTime = date.addingTimeInterval(TimeInterval(durationMin * 60))
            }

            context.insert(workout)

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
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
