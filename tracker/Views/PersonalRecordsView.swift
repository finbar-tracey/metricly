import SwiftUI
import SwiftData
import Charts

struct PersonalRecordsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate })
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    private var records: [PRRecord] {
        var best: [String: PRRecord] = [:]
        for workout in workouts {
            for exercise in workout.exercises {
                let workingSets = exercise.sets.filter { !$0.isWarmUp }
                guard let heaviest = workingSets.max(by: { $0.weight < $1.weight }),
                      heaviest.weight > 0 else { continue }

                let key = exercise.name.lowercased()
                if let existing = best[key] {
                    if heaviest.weight > existing.weight {
                        best[key] = PRRecord(
                            exerciseName: exercise.name,
                            weight: heaviest.weight,
                            reps: heaviest.reps,
                            date: workout.date,
                            category: exercise.category,
                            history: existing.history + [(workout.date, heaviest.weight)]
                        )
                    } else {
                        best[key]?.history.append((workout.date, heaviest.weight))
                    }
                } else {
                    best[key] = PRRecord(
                        exerciseName: exercise.name,
                        weight: heaviest.weight,
                        reps: heaviest.reps,
                        date: workout.date,
                        category: exercise.category,
                        history: [(workout.date, heaviest.weight)]
                    )
                }
            }
        }
        return best.values.sorted { $0.weight > $1.weight }
    }

    private var groupedRecords: [(MuscleGroup?, [PRRecord])] {
        let grouped = Dictionary(grouping: records, by: { $0.category })
        return grouped.sorted { ($0.key?.rawValue ?? "ZZZ") < ($1.key?.rawValue ?? "ZZZ") }
    }

    var body: some View {
        List {
            if records.isEmpty {
                ContentUnavailableView {
                    Label("No Records Yet", systemImage: "trophy")
                } description: {
                    Text("Complete workouts with tracked weights to see your personal records here.")
                }
                .listRowBackground(Color.clear)
            } else {
                // Top 3 highlight
                if records.count >= 3 {
                    Section("Top Lifts") {
                        ForEach(records.prefix(3)) { record in
                            topLiftRow(record)
                        }
                    }
                }

                ForEach(groupedRecords, id: \.0) { group, recs in
                    Section(group?.rawValue ?? "Uncategorized") {
                        ForEach(recs) { record in
                            prRow(record)
                        }
                    }
                }
            }
        }
        .navigationTitle("Personal Records")
    }

    private func topLiftRow(_ record: PRRecord) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "trophy.fill")
                .font(.title2)
                .foregroundStyle(.yellow)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(record.exerciseName)
                    .font(.headline)
                HStack(spacing: 6) {
                    Text(unit.format(record.weight))
                        .font(.title3.bold())
                        .foregroundStyle(.primary)
                    Text("× \(record.reps)")
                        .foregroundStyle(.secondary)
                }
                Text(record.date, format: .dateTime.month().day().year())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if record.history.count >= 2 {
                sparkline(record.sortedHistory)
                    .frame(width: 60, height: 30)
            }
        }
        .padding(.vertical, 4)
    }

    private func prRow(_ record: PRRecord) -> some View {
        HStack(spacing: 14) {
            if let cat = record.category {
                Image(systemName: cat.icon)
                    .font(.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
            } else {
                Image(systemName: "dumbbell")
                    .font(.body)
                    .foregroundStyle(.tint)
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(record.exerciseName)
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 4) {
                    Text(unit.format(record.weight))
                        .font(.subheadline.bold())
                    Text("× \(record.reps)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(record.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if record.history.count >= 2 {
                sparkline(record.sortedHistory)
                    .frame(width: 50, height: 24)
            }
        }
        .padding(.vertical, 2)
    }

    private func sparkline(_ data: [(Date, Double)]) -> some View {
        Chart(data, id: \.0) { point in
            LineMark(
                x: .value("Date", point.0),
                y: .value("Weight", unit.display(point.1))
            )
            .foregroundStyle(.tint)
            .interpolationMethod(.catmullRom)
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
    }
}

struct PRRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
    let reps: Int
    let date: Date
    let category: MuscleGroup?
    var history: [(Date, Double)]

    var sortedHistory: [(Date, Double)] {
        history.sorted { $0.0 < $1.0 }
    }
}

#Preview {
    NavigationStack {
        PersonalRecordsView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
