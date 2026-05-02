import SwiftUI
import SwiftData
import Charts

struct VolumeTrendsView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var unit

    @State private var timeRange: TimeRange = .weekly

    enum TimeRange: String, CaseIterable {
        case weekly = "Weekly"
        case monthly = "Monthly"
    }

    private var calendar: Calendar { Calendar.current }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                volumeChartCard
                if !muscleVolumeData.isEmpty { muscleBreakdownCard }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Volume Trends")
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.blue, Color.blue.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("This Week")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        Text(formatVolume(totalVolumeThisWeek))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white).monospacedDigit()
                    }
                    Spacer()
                    if totalVolumeLastWeek > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: volumeChange >= 0 ? "arrow.up" : "arrow.down")
                                .font(.caption.bold())
                            Text(String(format: "%.0f%%", abs(volumeChange))).font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: formatVolume(totalVolumeLastWeek), label: "Last Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: totalVolumeLastWeek > 0 ? String(format: "%+.0f%%", volumeChange) : "—", label: "WoW")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(workoutsThisWeek)", label: "Workouts")
                }
            }
            .padding(20)
        }
        .heroCard()
    }


    // MARK: - Volume Chart Card

    private var volumeChartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume Trend", icon: "chart.bar.fill", color: .blue)

            HStack(spacing: 6) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { timeRange = range }
                    } label: {
                        Text(range.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 16).padding(.vertical, 7)
                            .background(timeRange == range ? Color.blue : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(timeRange == range ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            if volumeData.isEmpty {
                Text("Not enough data yet.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 40)
            } else {
                Chart(volumeData) { point in
                    BarMark(
                        x: .value("Period", point.date, unit: timeRange == .weekly ? .weekOfYear : .month),
                        y: .value("Volume", unit.display(point.volume))
                    )
                    .foregroundStyle(Color.blue.gradient).cornerRadius(4)
                }
                .chartYAxisLabel(unit.label)
                .frame(height: 200).padding(.vertical, 4)
            }
        }
        .appCard()
    }

    // MARK: - Muscle Breakdown Card

    private var muscleBreakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume by Muscle (30 days)", icon: "figure.strengthtraining.traditional", color: .blue)

            let maxVol = muscleVolumeData.map(\.1).max() ?? 1

            VStack(spacing: 0) {
                ForEach(Array(muscleVolumeData.enumerated()), id: \.element.0) { idx, pair in
                    let (group, volume) = pair
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.blue.opacity(0.12)).frame(width: 34, height: 34)
                            MuscleIconView(group: group, color: Color.blue)
                                .frame(width: 14, height: 14)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(group.rawValue).font(.subheadline.weight(.medium))
                                Spacer()
                                Text(formatVolume(volume))
                                    .font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                            }
                            GradientProgressBar(value: volume / maxVol, color: .blue, height: 5)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < muscleVolumeData.count - 1 { Divider().padding(.leading, 64) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Computed

    private var volumeData: [VolumePoint] {
        let grouped: [(Date, Double)]
        switch timeRange {
        case .weekly: grouped = groupByWeek()
        case .monthly: grouped = groupByMonth()
        }
        return grouped.map { VolumePoint(date: $0.0, volume: $0.1) }
    }

    private var muscleVolumeData: [(MuscleGroup, Double)] {
        let recent = workouts.filter { $0.date >= (calendar.date(byAdding: .day, value: -30, to: .now) ?? .now) }
        var volumes: [MuscleGroup: Double] = [:]
        for workout in recent {
            for exercise in workout.exercises {
                guard let group = exercise.category else { continue }
                let vol = exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
                volumes[group, default: 0] += vol
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
            .flatMap(\.exercises).flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
    }

    private var totalVolumeLastWeek: Double {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: startOfWeek) else { return 0 }
        return workouts.filter { $0.date >= lastWeekStart && $0.date < startOfWeek }
            .flatMap(\.exercises).flatMap(\.sets)
            .filter { !$0.isWarmUp }
            .reduce(0.0) { $0 + Double($1.reps) * $1.weight }
    }

    private var volumeChange: Double {
        guard totalVolumeLastWeek > 0 else { return 0 }
        return ((totalVolumeThisWeek - totalVolumeLastWeek) / totalVolumeLastWeek) * 100
    }

    private var workoutsThisWeek: Int {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= startOfWeek }.count
    }

    private func groupByWeek() -> [(Date, Double)] {
        var weeks: [Date: Double] = [:]
        for workout in workouts {
            guard let weekStart = calendar.dateInterval(of: .weekOfYear, for: workout.date)?.start else { continue }
            let vol = workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            weeks[weekStart, default: 0] += vol
        }
        return weeks.sorted { $0.key < $1.key }
    }

    private func groupByMonth() -> [(Date, Double)] {
        var months: [Date: Double] = [:]
        for workout in workouts {
            guard let monthStart = calendar.dateInterval(of: .month, for: workout.date)?.start else { continue }
            let vol = workout.exercises.flatMap(\.sets).filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            months[monthStart, default: 0] += vol
        }
        return months.sorted { $0.key < $1.key }
    }

    private func formatVolume(_ volume: Double) -> String {
        let displayed = unit.display(volume)
        if displayed >= 1000 { return String(format: "%.1fk %@", displayed / 1000, unit.label) }
        return "\(Int(displayed)) \(unit.label)"
    }
}

struct VolumePoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

#Preview {
    NavigationStack { VolumeTrendsView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
