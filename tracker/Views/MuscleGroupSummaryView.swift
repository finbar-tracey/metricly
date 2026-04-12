import SwiftUI
import SwiftData
import Charts

struct MuscleGroupSummaryView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    @State private var selectedPeriod: Period = .thisWeek

    enum Period: String, CaseIterable, Identifiable {
        case thisWeek = "This Week"
        case lastWeek = "Last Week"
        case last30 = "30 Days"
        case allTime = "All Time"
        var id: String { rawValue }
    }

    var body: some View {
        List {
            Section {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(Period.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .listRowSeparator(.hidden)
            }

            if chartData.isEmpty {
                Section {
                    Text("No workout data for this period.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                }
            } else {
                Section {
                    barChart
                        .frame(height: 220)
                        .padding(.vertical, 8)
                } header: {
                    Text("Volume by Muscle Group")
                }

                Section {
                    ForEach(chartData) { item in
                        HStack {
                            Image(systemName: item.group.icon)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            Text(item.group.rawValue)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(formatVolume(item.volume))
                                    .font(.subheadline.bold().monospacedDigit())
                                Text("\(item.sets) sets")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(item.group.rawValue): \(formatVolume(item.volume)), \(item.sets) sets")
                    }
                } header: {
                    Text("Breakdown")
                }
            }
        }
        .navigationTitle("Muscle Groups")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Chart

    private var barChart: some View {
        Chart(chartData) { item in
            BarMark(
                x: .value("Volume", weightUnit.display(item.volume)),
                y: .value("Group", item.group.rawValue)
            )
            .foregroundStyle(colorFor(item.group).gradient)
            .cornerRadius(4)
        }
        .chartXAxisLabel(weightUnit.label)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Volume by muscle group, \(chartData.count) groups")
    }

    // MARK: - Data

    struct GroupData: Identifiable {
        let id = UUID()
        let group: MuscleGroup
        let volume: Double // in kg
        let sets: Int
    }

    private var filteredWorkouts: [Workout] {
        let calendar = Calendar.current
        let now = Date.now
        switch selectedPeriod {
        case .thisWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return workouts.filter { $0.date >= start }
        case .lastWeek:
            guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
                  let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart)
            else { return [] }
            return workouts.filter { $0.date >= lastWeekStart && $0.date < thisWeekStart }
        case .last30:
            guard let start = calendar.date(byAdding: .day, value: -30, to: now) else { return [] }
            return workouts.filter { $0.date >= start }
        case .allTime:
            return Array(workouts)
        }
    }

    private var chartData: [GroupData] {
        var volumeByGroup: [MuscleGroup: Double] = [:]
        var setsByGroup: [MuscleGroup: Int] = [:]

        for workout in filteredWorkouts {
            for exercise in workout.exercises {
                let group = exercise.category ?? .other
                let workingSets = exercise.sets.filter { !$0.isWarmUp }
                for s in workingSets {
                    let vol = Double(s.reps) * s.weight
                    volumeByGroup[group, default: 0] += vol
                    setsByGroup[group, default: 0] += 1
                }
            }
        }

        return volumeByGroup.keys
            .map { GroupData(group: $0, volume: volumeByGroup[$0] ?? 0, sets: setsByGroup[$0] ?? 0) }
            .sorted { $0.volume > $1.volume }
    }

    // MARK: - Helpers

    private func formatVolume(_ volumeKg: Double) -> String {
        let displayValue = weightUnit.display(volumeKg)
        if displayValue >= 1000 {
            return String(format: "%.1fk %@", displayValue / 1000, weightUnit.label)
        }
        return String(format: "%.0f %@", displayValue, weightUnit.label)
    }

    private func colorFor(_ group: MuscleGroup) -> Color {
        switch group {
        case .chest: return .red
        case .back: return .blue
        case .shoulders: return .orange
        case .biceps: return .purple
        case .triceps: return .indigo
        case .legs: return .green
        case .core: return .yellow
        case .cardio: return .cyan
        case .other: return .gray
        }
    }
}
