import SwiftUI
import SwiftData
import Charts

struct OneRepMaxView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    @State private var selectedExercise: String?
    @State private var formula: E1RMFormula = .epley

    enum E1RMFormula: String, CaseIterable {
        case epley = "Epley"
        case brzycki = "Brzycki"

        func calculate(weight: Double, reps: Int) -> Double {
            guard reps > 0, weight > 0 else { return 0 }
            if reps == 1 { return weight }
            switch self {
            case .epley:
                return weight * (1 + Double(reps) / 30.0)
            case .brzycki:
                return weight * (36.0 / (37.0 - Double(reps)))
            }
        }
    }

    private var exerciseNames: [String] {
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

    private var e1rmHistory: [(Date, Double)] {
        guard let name = selectedExercise else { return [] }
        var history: [(Date, Double)] = []

        for workout in workouts {
            for exercise in workout.exercises where exercise.name == name {
                let workingSets = exercise.sets.filter { !$0.isWarmUp && $0.weight > 0 }
                guard !workingSets.isEmpty else { continue }
                let best = workingSets.map { formula.calculate(weight: $0.weight, reps: $0.reps) }.max() ?? 0
                if best > 0 {
                    history.append((workout.date, best))
                }
            }
        }

        return history.sorted { $0.0 < $1.0 }
    }

    private var currentE1RM: Double {
        e1rmHistory.last?.1 ?? 0
    }

    private var peakE1RM: Double {
        e1rmHistory.map(\.1).max() ?? 0
    }

    var body: some View {
        List {
            // Exercise picker
            Section("Exercise") {
                if exerciseNames.isEmpty {
                    Text("Complete some workouts to see estimated 1RM data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Exercise", selection: $selectedExercise) {
                        Text("Select...").tag(nil as String?)
                        ForEach(exerciseNames, id: \.self) { name in
                            Text(name).tag(name as String?)
                        }
                    }
                }
            }

            if let _ = selectedExercise, !e1rmHistory.isEmpty {
                // Stats
                Section {
                    HStack(spacing: 0) {
                        VStack(spacing: 4) {
                            Text("Current")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(unit.format(currentE1RM))
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text("Peak")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(unit.format(peakE1RM))
                                .font(.title3.bold())
                                .foregroundStyle(.green)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 4) {
                            Text("Sessions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(e1rmHistory.count)")
                                .font(.title3.bold())
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 4)
                }

                // Chart
                Section("Estimated 1RM Trend") {
                    Chart(e1rmHistory, id: \.0) { point in
                        LineMark(
                            x: .value("Date", point.0),
                            y: .value("E1RM", unit.display(point.1))
                        )
                        .foregroundStyle(.blue.gradient)
                        .interpolationMethod(.catmullRom)

                        AreaMark(
                            x: .value("Date", point.0),
                            y: .value("E1RM", unit.display(point.1))
                        )
                        .foregroundStyle(.blue.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)

                        PointMark(
                            x: .value("Date", point.0),
                            y: .value("E1RM", unit.display(point.1))
                        )
                        .foregroundStyle(.blue)
                        .symbolSize(20)
                    }
                    .chartYAxisLabel(unit.label)
                    .frame(height: 200)
                    .padding(.vertical, 8)
                }

                // Formula picker
                Section {
                    Picker("Formula", selection: $formula) {
                        ForEach(E1RMFormula.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    switch formula {
                    case .epley:
                        Text("Epley: weight × (1 + reps/30). Best for 1-10 rep ranges.")
                    case .brzycki:
                        Text("Brzycki: weight × 36/(37 - reps). Most accurate for lower rep sets.")
                    }
                }
            }
        }
        .navigationTitle("Estimated 1RM")
        .onAppear {
            if selectedExercise == nil {
                selectedExercise = exerciseNames.first
            }
        }
    }
}

#Preview {
    NavigationStack {
        OneRepMaxView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
