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
        HeroCard(palette: [
            Color(red: 0.55, green: 0.30, blue: 0.95),
            Color(red: 0.55, green: 0.40, blue: 0.92),
            AppTheme.Signal.calm
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedPeriod.rawValue)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(formatVolume(totalVolume))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.right.circle.fill").font(.caption.bold())
                        Text("\(totalSets) sets").font(.caption.bold())
                    }
                    .padding(.horizontal, 11).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                    .foregroundStyle(.white)
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(chartData.count)", label: "Muscles")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(filteredWorkouts.count)", label: "Workouts")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: chartData.first?.group.rawValue ?? "—", label: "Top")
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
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
                    VStack(spacing: 10) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [colorFor(item.group).opacity(0.20), colorFor(item.group).opacity(0.10)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 38, height: 38)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                                            .stroke(colorFor(item.group).opacity(0.20), lineWidth: 0.5)
                                    )
                                MuscleIconView(group: item.group, color: colorFor(item.group))
                                    .frame(width: 16, height: 16)
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.group.rawValue)
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                Text("\(item.sets) sets")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(formatVolume(item.volume))
                                .font(.system(size: 15, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(colorFor(item.group))
                        }
                        GradientProgressBar(value: item.volume / maxVol, color: colorFor(item.group), height: 6)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(item.group.rawValue): \(formatVolume(item.volume)), \(item.sets) sets")

                    if idx < chartData.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
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
