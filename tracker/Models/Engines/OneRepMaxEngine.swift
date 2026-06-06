import Foundation

/// Pure estimated-1RM math — formulas, history, training zones.
enum OneRepMaxEngine {

    enum Formula: String, CaseIterable {
        case epley = "Epley"
        case brzycki = "Brzycki"

        func calculate(weight: Double, reps: Int) -> Double {
            guard reps > 0, weight > 0 else { return 0 }
            if reps == 1 { return weight }
            switch self {
            case .epley:
                return weight * (1 + Double(reps) / 30.0)
            case .brzycki:
                // Brzycki's denominator (37 − reps) hits zero at 37 reps and
                // turns negative beyond, yielding infinite/negative 1RMs. Past
                // its valid range, fall back to Epley.
                guard reps < 37 else { return weight * (1 + Double(reps) / 30.0) }
                return weight * (36.0 / (37.0 - Double(reps)))
            }
        }
    }

    static func exerciseNames(from workouts: [Workout]) -> [String] {
        var names: [String: Double] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let workingSets = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
                guard !workingSets.isEmpty else { continue }
                let maxWeight = workingSets.map(\.weight).max() ?? 0
                names[exercise.name] = max(names[exercise.name] ?? 0, maxWeight)
            }
        }
        return names.sorted { $0.value > $1.value }.map(\.key)
    }

    static func e1rmHistory(
        workouts: [Workout],
        exerciseName: String,
        formula: Formula
    ) -> [(Date, Double)] {
        var history: [(Date, Double)] = []
        for workout in workouts {
            for exercise in workout.exercises where exercise.name == exerciseName {
                let workingSets = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
                guard !workingSets.isEmpty else { continue }
                let best = workingSets.map { formula.calculate(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                if best > 0 { history.append((workout.date, best)) }
            }
        }
        return history.sorted { $0.0 < $1.0 }
    }

    static func percentageRows(base: Double) -> [(label: String, value: Double)] {
        guard base > 0 else { return [] }
        return [100, 95, 90, 85, 80, 75, 70, 65, 60].map { pct in
            ("\(pct)%", base * Double(pct) / 100.0)
        }
    }

    /// Epley estimate used by exercise history charts.
    static func epleyEstimate(weight: Double, reps: Int) -> Double {
        Formula.epley.calculate(weight: weight, reps: reps)
    }
}
