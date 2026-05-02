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
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                periodPickerCard
                if chartData.isEmpty {
                    emptyStateCard
                } else {
                    heroCard
                    chartCard
                    breakdownCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Muscle Groups")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Period Picker Card

    private var periodPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Time Period", icon: "calendar", color: .accentColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Period.allCases) { period in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedPeriod = period
                            }
                        } label: {
                            Text(period.rawValue)
                                .font(.caption.bold())
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selectedPeriod == period ? Color.accentColor : Color(.secondarySystemFill),
                                            in: Capsule())
                                .foregroundStyle(selectedPeriod == period ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedPeriod.rawValue)
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        Text(formatVolume(totalVolume))
                            .font(.system(size: 36, weight: .black, design: .rounded))
                            .foregroundStyle(.white).monospacedDigit()
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle.fill").font(.caption.bold())
                        Text("\(totalSets) sets").font(.caption.bold())
                    }
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(.white.opacity(0.20), in: Capsule())
                    .foregroundStyle(.white)
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(chartData.count)", label: "Muscles")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(filteredWorkouts.count)", label: "Workouts")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: chartData.first?.group.rawValue ?? "—", label: "Top")
                }
            }
            .padding(20)
        }
        .heroCard()
    }


    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Volume by Muscle Group", icon: "chart.bar.fill", color: .accentColor)
            Chart(chartData) { item in
                BarMark(
                    x: .value("Volume", weightUnit.display(item.volume)),
                    y: .value("Group", item.group.rawValue)
                )
                .foregroundStyle(colorFor(item.group).gradient)
                .cornerRadius(4)
            }
            .chartXAxisLabel(weightUnit.label)
            .frame(height: 220)
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Volume by muscle group, \(chartData.count) groups")
        }
        .appCard()
    }

    // MARK: - Breakdown Card

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Breakdown", icon: "list.bullet.rectangle", color: .accentColor)

            let maxVol = chartData.first?.volume ?? 1

            VStack(spacing: 0) {
                ForEach(Array(chartData.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(colorFor(item.group).opacity(0.12))
                                    .frame(width: 34, height: 34)
                                MuscleIconView(group: item.group, color: colorFor(item.group))
                                    .frame(width: 14, height: 14)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.group.rawValue).font(.subheadline.weight(.semibold))
                                Text("\(item.sets) sets").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatVolume(item.volume))
                                .font(.subheadline.bold().monospacedDigit())
                        }
                        GradientProgressBar(value: item.volume / maxVol, color: colorFor(item.group), height: 4)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.group.rawValue): \(formatVolume(item.volume)), \(item.sets) sets")

                    if idx < chartData.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("No Data").font(.headline)
                Text("No workout data for \(selectedPeriod.rawValue.lowercased()).")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Data

    struct GroupData: Identifiable {
        let id = UUID()
        let group: MuscleGroup
        let volume: Double
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
                    volumeByGroup[group, default: 0] += Double(s.reps) * s.weight
                    setsByGroup[group, default: 0] += 1
                }
            }
        }

        return volumeByGroup.keys
            .map { GroupData(group: $0, volume: volumeByGroup[$0] ?? 0, sets: setsByGroup[$0] ?? 0) }
            .sorted { $0.volume > $1.volume }
    }

    private var totalVolume: Double { chartData.reduce(0) { $0 + $1.volume } }
    private var totalSets: Int { chartData.reduce(0) { $0 + $1.sets } }

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
