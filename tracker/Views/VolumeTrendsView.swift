import SwiftUI
import SwiftData
import Charts

struct VolumeTrendsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    @State private var timeRange: TimeRange = .weekly
    @State private var selectedGroup: MuscleGroup?

    enum TimeRange: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    private var calendar: Calendar { Calendar.current }

    private var volumeData: [VolumePoint] {
        let grouped: [(Date, Double)]

        switch timeRange {
        case .weekly:
            grouped = groupByWeek()
        case .monthly:
            grouped = groupByMonth()
        }

        return grouped.map { VolumePoint(date: $0.0, volume: $0.1) }
    }

    private var muscleVolumeData: [(MuscleGroup, Double)] {
        let recent = workouts.filter {
            $0.date >= (calendar.date(byAdding: .day, value: -30, to: .now) ?? .now)
        }

        var volumes: [MuscleGroup: Double] = [:]
        for workout in recent {
            for exercise in workout.exercises {
                guard let group = exercise.category else { continue }
                let exerciseVolume = exercise.sets
                    .filter { !$0.isWarmUp }
                    .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
                volumes[group, default: 0] += exerciseVolume
            }
        }

        return MuscleGroup.allCases
            .filter { $0 != .cardio && $0 != .other }
            .compactMap { group in
                guard let vol = volumes[group], vol > 0 else { return nil }
                return (group, vol)
            }
            .sorted { $0.1 > $1.1 }
    }

    private var totalVolumeThisWeek: Double {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= startOfWeek }
            .flatMap(\.exercises)
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
    }

    private var totalVolumeLastWeek: Double {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: startOfWeek) else { return 0 }
        return workouts.filter { $0.date >= lastWeekStart && $0.date < startOfWeek }
            .flatMap(\.exercises)
            .flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
    }

    private var volumeChange: Double {
        guard totalVolumeLastWeek > 0 else { return 0 }
        return ((totalVolumeThisWeek - totalVolumeLastWeek) / totalVolumeLastWeek) * 100
    }

    var body: some View {
        List {
            // Summary stats
            Section {
                HStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("This Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatVolume(totalVolumeThisWeek))
                            .font(.title3.bold())
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("Last Week")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(formatVolume(totalVolumeLastWeek))
                            .font(.title3.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 4) {
                        Text("Change")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            Image(systemName: volumeChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption)
                            Text(String(format: "%.0f%%", volumeChange))
                                .font(.title3.bold())
                        }
                        .foregroundStyle(volumeChange >= 0 ? .green : .red)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 4)
            }

            // Volume trend chart
            Section("Volume Trend") {
                Picker("Range", selection: $timeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)

                if !volumeData.isEmpty {
                    Chart(volumeData) { point in
                        BarMark(
                            x: .value("Period", point.date, unit: timeRange == .weekly ? .weekOfYear : .month),
                            y: .value("Volume", unit.display(point.volume))
                        )
                        .foregroundStyle(.blue.gradient)
                        .cornerRadius(4)
                    }
                    .chartYAxisLabel(unit.label)
                    .frame(height: 200)
                    .padding(.vertical, 8)
                } else {
                    Text("Not enough data yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Volume by muscle group (last 30 days)
            if !muscleVolumeData.isEmpty {
                Section("Volume by Muscle (30 days)") {
                    Chart(muscleVolumeData, id: \.0) { group, volume in
                        BarMark(
                            x: .value("Volume", unit.display(volume)),
                            y: .value("Muscle", group.rawValue)
                        )
                        .foregroundStyle(by: .value("Group", group.rawValue))
                        .cornerRadius(4)
                    }
                    .chartLegend(.hidden)
                    .chartXAxisLabel(unit.label)
                    .frame(height: CGFloat(muscleVolumeData.count) * 36)
                    .padding(.vertical, 8)

                    ForEach(muscleVolumeData, id: \.0) { group, volume in
                        HStack {
                            Image(systemName: group.icon)
                                .foregroundStyle(.tint)
                                .frame(width: 24)
                            Text(group.rawValue)
                                .font(.subheadline)
                            Spacer()
                            Text(formatVolume(volume))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Volume Trends")
    }

    private func groupByWeek() -> [(Date, Double)] {
        var weeks: [Date: Double] = [:]
        for workout in workouts {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start else { continue }
            let vol = workout.exercises.flatMap(\.sets)
                .filter { !$0.isWarmUp }
                .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            weeks[weekStart, default: 0] += vol
        }
        return weeks.sorted { $0.key < $1.key }
    }

    private func groupByMonth() -> [(Date, Double)] {
        var months: [Date: Double] = [:]
        for workout in workouts {
            guard let monthStart = calendar.dateInterval(of: .month, for: workout.date)?.start else { continue }
            let vol = workout.exercises.flatMap(\.sets)
                .filter { !$0.isWarmUp }
                .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            months[monthStart, default: 0] += vol
        }
        return months.sorted { $0.key < $1.key }
    }

    private func formatVolume(_ volume: Double) -> String {
        let displayed = unit.display(volume)
        if displayed >= 1000 {
            return String(format: "%.1fk %@", displayed / 1000, unit.label)
        }
        return "\(Int(displayed)) \(unit.label)"
    }
}

struct VolumePoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

#Preview {
    NavigationStack {
        VolumeTrendsView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
