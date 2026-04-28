import SwiftUI
import SwiftData
import HealthKit

enum ReportPeriod: String, CaseIterable {
    case week = "This Week"
    case month = "This Month"
}

struct WeeklyMonthlyReportView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Query(sort: \BodyWeightEntry.date) private var allBodyWeightEntries: [BodyWeightEntry]
    @Query private var settingsArray: [UserSettings]
    @Environment(\.weightUnit) private var weightUnit

    @State private var selectedPeriod: ReportPeriod = .week
    @State private var showingShare = false
    @State private var shareImage: UIImage?

    @State private var avgSteps: Double?
    @State private var avgSleepMinutes: Double?
    @State private var avgRestingHR: Double?
    @State private var avgHRV: Double?
    @State private var prevAvgSteps: Double?
    @State private var prevAvgSleepMinutes: Double?
    @State private var prevAvgRestingHR: Double?
    @State private var prevAvgHRV: Double?
    @State private var isLoadingHealth = false

    // MARK: - Date Ranges

    private var currentPeriodRange: (start: Date, end: Date) {
        let calendar = Calendar.current; let now = Date.now
        switch selectedPeriod {
        case .week:
            let start = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
            return (start, now)
        case .month:
            let start = calendar.dateInterval(of: .month, for: now)?.start ?? now
            return (start, now)
        }
    }

    private var previousPeriodRange: (start: Date, end: Date) {
        let calendar = Calendar.current; let current = currentPeriodRange
        switch selectedPeriod {
        case .week:
            return (calendar.date(byAdding: .day, value: -7, to: current.start)!, current.start)
        case .month:
            return (calendar.date(byAdding: .month, value: -1, to: current.start)!, current.start)
        }
    }

    private var periodWorkouts: [Workout] {
        let range = currentPeriodRange
        return allWorkouts.filter { $0.date >= range.start && $0.date <= range.end }
    }

    private var previousPeriodWorkouts: [Workout] {
        let range = previousPeriodRange
        return allWorkouts.filter { $0.date >= range.start && $0.date < range.end }
    }

    private var workoutsBeforePeriod: [Workout] {
        let range = currentPeriodRange; return allWorkouts.filter { $0.date < range.start }
    }

    // MARK: - Training Summary

    private var workoutCount: Int { periodWorkouts.count }

    private var totalSets: Int {
        periodWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp && !$0.isCardio }.count }
        }
    }

    private var totalVolumeKg: Double {
        periodWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
    }

    private var totalVolume: Double { weightUnit == .kg ? totalVolumeKg : totalVolumeKg * 2.20462 }

    private var totalDuration: TimeInterval {
        periodWorkouts.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    private var formattedDuration: String {
        let totalMinutes = Int(totalDuration) / 60
        let hours = totalMinutes / 60; let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private var volumeChange: Double? {
        let prevVolumeKg = previousPeriodWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
        guard prevVolumeKg > 0 else { return nil }
        return ((totalVolumeKg - prevVolumeKg) / prevVolumeKg) * 100
    }

    private var prExerciseNames: [String] {
        var historicalMax: [String: Double] = [:]
        for workout in workoutsBeforePeriod {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                let key = exercise.name.lowercased()
                historicalMax[key] = Swift.max(historicalMax[key] ?? 0, maxWeight)
            }
        }
        var prNames: [String] = []
        for workout in periodWorkouts {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                let key = exercise.name.lowercased()
                if maxWeight > 0, maxWeight > (historicalMax[key] ?? 0) {
                    prNames.append(exercise.name); historicalMax[key] = maxWeight
                }
            }
        }
        return prNames
    }

    private var prsHitCount: Int { prExerciseNames.count }

    private var muscleGroupSetCounts: [(group: MuscleGroup, sets: Int)] {
        var counts: [MuscleGroup: Int] = [:]
        for workout in periodWorkouts {
            for exercise in workout.exercises {
                if let group = exercise.category {
                    counts[group, default: 0] += exercise.sets.filter { !$0.isWarmUp }.count
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    private var periodBodyWeightEntries: [BodyWeightEntry] {
        let range = currentPeriodRange
        return allBodyWeightEntries.filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date < $1.date }
    }

    private var bodyWeightStart: Double? { periodBodyWeightEntries.first?.weight }
    private var bodyWeightEnd: Double? { periodBodyWeightEntries.last?.weight }

    private var bodyWeightChange: Double? {
        guard let start = bodyWeightStart, let end = bodyWeightEnd,
              periodBodyWeightEntries.count >= 2 else { return nil }
        let diff = end - start; guard abs(diff) > 0.01 else { return nil }
        return diff
    }

    private var currentStreak: Int { Workout.currentStreak(from: allWorkouts) }

    private var workoutsPerWeekAverage: Double? {
        guard selectedPeriod == .month, !periodWorkouts.isEmpty else { return nil }
        let range = currentPeriodRange
        let daysPassed = max(1, Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 1)
        return Double(periodWorkouts.count) / max(1.0, Double(daysPassed) / 7.0)
    }

    private var bestDay: String? {
        guard !periodWorkouts.isEmpty else { return nil }
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        for workout in periodWorkouts { dayCounts[calendar.component(.weekday, from: workout.date), default: 0] += 1 }
        guard let bestWeekday = dayCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        return DateFormatter().weekdaySymbols[bestWeekday - 1]
    }

    private var periodLabel: String {
        let formatter = DateFormatter(); let range = currentPeriodRange
        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "MMM d"
            let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: range.start)!
            return "\(formatter.string(from: range.start)) – \(formatter.string(from: min(endOfWeek, .now)))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"; return formatter.string(from: range.start)
        }
    }

    private var vibeEmoji: String {
        if periodWorkouts.isEmpty { return "😴" }
        let daysPassed = max(1, Calendar.current.dateComponents([.day], from: currentPeriodRange.start, to: .now).day ?? 1)
        let frequency = Double(periodWorkouts.count) / Double(daysPassed) * 7.0
        if prsHitCount >= 3 && frequency >= 4 { return "🔥" }
        if prsHitCount >= 1 && frequency >= 3 { return "💪" }
        if frequency >= 3 { return "✅" }
        if frequency >= 1 { return "👍" }
        return "🌱"
    }

    private var healthKitEnabled: Bool { settingsArray.first?.healthKitEnabled ?? false }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                periodPickerCard
                heroCard
                trainingSummaryCard

                if prsHitCount > 0 { prsCard }
                if !muscleGroupSetCounts.isEmpty { muscleGroupsCard }
                if periodBodyWeightEntries.count >= 2 { bodyWeightCard }
                if healthKitEnabled { healthSummaryCard }
                consistencyCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { shareAsImage() } label: { Image(systemName: "square.and.arrow.up") }
                    .disabled(periodWorkouts.isEmpty)
            }
        }
        .sheet(isPresented: $showingShare) {
            if let image = shareImage { ShareSheet(items: [image]) }
        }
        .task(id: selectedPeriod) {
            guard healthKitEnabled else { return }
            await loadHealthData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            avgSteps = nil; avgSleepMinutes = nil; avgRestingHR = nil; avgHRV = nil
            prevAvgSteps = nil; prevAvgSleepMinutes = nil; prevAvgRestingHR = nil; prevAvgHRV = nil
        }
    }

    // MARK: - Period Picker Card

    private var periodPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Period", icon: "calendar", color: .accentColor)
            HStack(spacing: 8) {
                ForEach(ReportPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPeriod = period }
                    } label: {
                        Text(period.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(selectedPeriod == period ? Color.accentColor : Color(.secondarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(selectedPeriod == period ? .white : .primary)
                    }
                    .buttonStyle(.plain)
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
                    Text(vibeEmoji).font(.system(size: 38))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(selectedPeriod == .week ? "Weekly Report" : "Monthly Report")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        Text(periodLabel)
                            .font(.title3.weight(.bold)).foregroundStyle(.white)
                    }
                    Spacer()
                    if prsHitCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.caption.bold())
                            Text("\(prsHitCount) PR\(prsHitCount == 1 ? "" : "s")").font(.caption.bold())
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())
                        .foregroundStyle(.white)
                    }
                }

                if periodWorkouts.isEmpty {
                    Text("No workouts logged \(selectedPeriod == .week ? "this week" : "this month") yet.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.75))
                } else {
                    HStack(spacing: 0) {
                        heroStatCol("Workouts", value: "\(workoutCount)")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                        heroStatCol("Sets", value: "\(totalSets)")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                        heroStatCol("Duration", value: formattedDuration)
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                        heroStatCol("Volume", value: formatVolume(totalVolume))
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    private func heroStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.white.opacity(0.70))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Training Summary Card

    @ViewBuilder
    private var trainingSummaryCard: some View {
        if !periodWorkouts.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Training Summary", icon: "figure.strengthtraining.traditional", color: .accentColor)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    statTile(icon: "dumbbell.fill", value: "\(workoutCount)", label: "Workouts", color: .blue)
                    statTile(icon: "clock.fill", value: formattedDuration, label: "Total Time", color: .green)
                    statTile(icon: "scalemass.fill", value: formatVolume(totalVolume), label: "Volume", color: .purple, change: volumeChange)
                    statTile(icon: "number", value: "\(totalSets)", label: "Sets", color: .orange)
                }
            }
            .appCard()
        }
    }

    private func statTile(icon: String, value: String, label: String, color: Color, change: Double? = nil) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(color.opacity(0.12)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(color)
            }
            Text(value).font(.system(size: 18, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right").imageScale(.small)
                    Text(String(format: "%+.0f%%", change))
                }
                .font(.caption2.bold())
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - PRs Card

    private var prsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Personal Records", icon: "star.fill", color: .yellow)

            VStack(spacing: 0) {
                ForEach(Array(prExerciseNames.prefix(5).enumerated()), id: \.offset) { idx, name in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.yellow.opacity(0.15)).frame(width: 32, height: 32)
                            Image(systemName: "star.fill")
                                .font(.system(size: 12, weight: .semibold)).foregroundStyle(.yellow)
                        }
                        Text(name).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("New PR").font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Color.yellow.opacity(0.15), in: Capsule())
                            .foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < min(prExerciseNames.count, 5) - 1 { Divider().padding(.leading, 60) }
                }
                if prExerciseNames.count > 5 {
                    Text("+ \(prExerciseNames.count - 5) more PRs")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 16).padding(.vertical, 10)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Muscle Groups Card

    private var muscleGroupsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Muscle Groups", icon: "figure.strengthtraining.traditional", color: .accentColor)

            let maxSets = Double(muscleGroupSetCounts.first?.sets ?? 1)
            VStack(spacing: 10) {
                ForEach(muscleGroupSetCounts.prefix(6), id: \.group) { item in
                    HStack(spacing: 10) {
                        Image(systemName: item.group.icon)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 20)
                        Text(item.group.rawValue)
                            .font(.caption.weight(.medium))
                            .frame(width: 70, alignment: .leading)
                        GradientProgressBar(value: Double(item.sets) / maxSets, color: .accentColor, height: 6)
                        Text("\(item.sets)")
                            .font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
                            .frame(width: 24, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Body Weight Card

    @ViewBuilder
    private var bodyWeightCard: some View {
        if let startW = bodyWeightStart, let endW = bodyWeightEnd {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Body Weight", icon: "scalemass.fill", color: .indigo)

                VStack(spacing: 0) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Start").font(.caption2).foregroundStyle(.tertiary)
                            Text(weightUnit.format(startW))
                                .font(.title3.bold().monospacedDigit())
                        }
                        Spacer()
                        Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("Latest").font(.caption2).foregroundStyle(.tertiary)
                            Text(weightUnit.format(endW))
                                .font(.title3.bold().monospacedDigit())
                        }
                        if let change = bodyWeightChange {
                            Spacer()
                            VStack(alignment: .trailing, spacing: 3) {
                                Text("Change").font(.caption2).foregroundStyle(.tertiary)
                                HStack(spacing: 2) {
                                    Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right").imageScale(.small)
                                    Text(weightUnit.format(abs(change)))
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(change > 0 ? .red : .green)
                            }
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .appCard()
        }
    }

    // MARK: - Health Summary Card

    @ViewBuilder
    private var healthSummaryCard: some View {
        if avgSteps != nil || avgSleepMinutes != nil || avgRestingHR != nil || avgHRV != nil {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Health Summary", icon: "heart.fill", color: .red)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    if let steps = avgSteps {
                        healthTile(icon: "figure.walk", value: HealthFormatters.formatSteps(steps),
                                   label: "Avg Steps", color: .green,
                                   trend: trendInfo(current: steps, previous: prevAvgSteps, higherIsBetter: true))
                    }
                    if let sleep = avgSleepMinutes {
                        healthTile(icon: "bed.double.fill", value: HealthFormatters.formatSleepShort(sleep),
                                   label: "Avg Sleep", color: .indigo,
                                   trend: trendInfo(current: sleep, previous: prevAvgSleepMinutes, higherIsBetter: true))
                    }
                    if let hr = avgRestingHR {
                        healthTile(icon: "heart.fill", value: "\(Int(hr)) bpm",
                                   label: "Resting HR", color: .red,
                                   trend: trendInfo(current: hr, previous: prevAvgRestingHR, higherIsBetter: false))
                    }
                    if let hrv = avgHRV {
                        healthTile(icon: "waveform.path.ecg", value: "\(Int(hrv)) ms",
                                   label: "HRV", color: .purple,
                                   trend: trendInfo(current: hrv, previous: prevAvgHRV, higherIsBetter: true))
                    }
                }
            }
            .appCard()
        } else if isLoadingHealth {
            HStack(spacing: 12) {
                ProgressView().tint(.secondary)
                Text("Loading health data…").font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .appCard()
        }
    }

    private func healthTile(icon: String, value: String, label: String, color: Color, trend: (icon: String, isGood: Bool)?) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(value).font(.subheadline.bold().monospacedDigit())
                    if let trend {
                        Image(systemName: trend.icon).font(.caption2)
                            .foregroundStyle(trend.isGood ? .green : .red)
                    }
                }
                Text(label).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Consistency Card

    private var consistencyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Consistency", icon: "flame.fill", color: .orange)

            VStack(spacing: 0) {
                consistencyRow(icon: "flame.fill", color: .orange, label: "Day Streak", value: "\(currentStreak) days")
                if let wpw = workoutsPerWeekAverage {
                    Divider().padding(.leading, 16)
                    consistencyRow(icon: "chart.bar.fill", color: .blue, label: "Per Week Avg",
                                   value: String(format: "%.1f workouts", wpw))
                }
                if let best = bestDay {
                    Divider().padding(.leading, 16)
                    consistencyRow(icon: "star.fill", color: .yellow, label: "Best Day", value: best)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func consistencyRow(icon: String, color: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.bold().monospacedDigit())
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Trend Helper

    private func trendInfo(current: Double, previous: Double?, higherIsBetter: Bool) -> (icon: String, isGood: Bool)? {
        guard let prev = previous, prev > 0 else { return nil }
        let diff = current - prev; guard abs(diff / prev) > 0.02 else { return nil }
        let goingUp = diff > 0; let isGood = goingUp == higherIsBetter
        return (goingUp ? "arrow.up.right" : "arrow.down.right", isGood)
    }

    // MARK: - HealthKit Loading

    private func loadHealthData() async {
        isLoadingHealth = true; defer { isLoadingHealth = false }
        let hk = HealthKitManager.shared; let days: Int = selectedPeriod == .week ? 14 : 60
        let range = currentPeriodRange; let prevRange = previousPeriodRange

        async let stepsResult = hk.fetchDailySteps(days: days)
        async let sleepResult = hk.fetchDailySleep(days: days)
        async let hrResult = hk.fetchDailyRestingHeartRate(days: days)
        async let hrvResult = hk.fetchDailyHRV(days: days)

        if let steps = try? await stepsResult {
            let current = steps.filter { $0.date >= range.start }
            avgSteps = current.isEmpty ? nil : current.map(\.steps).reduce(0, +) / Double(current.count)
            let prev = steps.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgSteps = prev.isEmpty ? nil : prev.map(\.steps).reduce(0, +) / Double(prev.count)
        }
        if let sleep = try? await sleepResult {
            let current = sleep.filter { $0.date >= range.start }
            avgSleepMinutes = current.isEmpty ? nil : current.map(\.minutes).reduce(0, +) / Double(current.count)
            let prev = sleep.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgSleepMinutes = prev.isEmpty ? nil : prev.map(\.minutes).reduce(0, +) / Double(prev.count)
        }
        if let hr = try? await hrResult {
            let current = hr.filter { $0.date >= range.start }
            avgRestingHR = current.isEmpty ? nil : current.map(\.bpm).reduce(0, +) / Double(current.count)
            let prev = hr.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgRestingHR = prev.isEmpty ? nil : prev.map(\.bpm).reduce(0, +) / Double(prev.count)
        }
        if let hrv = try? await hrvResult {
            let current = hrv.filter { $0.date >= range.start }
            avgHRV = current.isEmpty ? nil : current.map(\.ms).reduce(0, +) / Double(current.count)
            let prev = hrv.filter { $0.date >= prevRange.start && $0.date < prevRange.end }
            prevAvgHRV = prev.isEmpty ? nil : prev.map(\.ms).reduce(0, +) / Double(prev.count)
        }
    }

    // MARK: - Share

    @MainActor
    private func shareAsImage() {
        let shareCard = ReportShareCardView(
            periodLabel: periodLabel, selectedPeriod: selectedPeriod, vibeEmoji: vibeEmoji,
            workoutCount: workoutCount, totalSets: totalSets, totalVolume: totalVolume,
            formattedDuration: formattedDuration, volumeChange: volumeChange,
            prsHitCount: prsHitCount, prExerciseNames: prExerciseNames,
            muscleGroupSetCounts: muscleGroupSetCounts,
            bodyWeightStart: bodyWeightStart, bodyWeightEnd: bodyWeightEnd, bodyWeightChange: bodyWeightChange,
            avgSteps: avgSteps, avgSleepMinutes: avgSleepMinutes, avgRestingHR: avgRestingHR, avgHRV: avgHRV,
            currentStreak: currentStreak, weightUnit: weightUnit
        )
        let renderer = ImageRenderer(content:
            shareCard.frame(width: 380).padding(16).background(Color(.systemGroupedBackground))
        )
        renderer.scale = 3.0
        if let image = renderer.uiImage { shareImage = image; showingShare = true }
    }

    // MARK: - Formatting

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 { return String(format: "%.1fk %@", volume / 1000, weightUnit.label) }
        return String(format: "%.0f %@", volume, weightUnit.label)
    }
}

// MARK: - Share Card (preserved exactly)

struct ReportShareCardView: View {
    let periodLabel: String
    let selectedPeriod: ReportPeriod
    let vibeEmoji: String
    let workoutCount: Int
    let totalSets: Int
    let totalVolume: Double
    let formattedDuration: String
    let volumeChange: Double?
    let prsHitCount: Int
    let prExerciseNames: [String]
    let muscleGroupSetCounts: [(group: MuscleGroup, sets: Int)]
    let bodyWeightStart: Double?
    let bodyWeightEnd: Double?
    let bodyWeightChange: Double?
    let avgSteps: Double?
    let avgSleepMinutes: Double?
    let avgRestingHR: Double?
    let avgHRV: Double?
    let currentStreak: Int
    let weightUnit: WeightUnit

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(vibeEmoji).font(.system(size: 36))
                Text(selectedPeriod == .week ? "Weekly Report" : "Monthly Report").font(.title2.bold())
                Text(periodLabel).font(.subheadline).foregroundStyle(.secondary)
            }
            .padding(20).frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1))

            HStack(spacing: 0) {
                shareStatItem(value: "\(workoutCount)", label: "Workouts")
                Divider().frame(height: 36)
                shareStatItem(value: "\(totalSets)", label: "Sets")
                Divider().frame(height: 36)
                shareStatItem(value: formatVolume(totalVolume), label: "Volume")
                Divider().frame(height: 36)
                shareStatItem(value: formattedDuration, label: "Duration")
            }
            .padding(.vertical, 12)

            Divider()

            if prsHitCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("\(prsHitCount) PR\(prsHitCount == 1 ? "" : "s")").font(.subheadline.bold())
                    Text(prExerciseNames.prefix(3).joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if !muscleGroupSetCounts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(muscleGroupSetCounts.prefix(5), id: \.group) { item in
                        Text(item.group.rawValue).font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                    if muscleGroupSetCounts.count > 5 {
                        Text("+\(muscleGroupSetCounts.count - 5)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if let startW = bodyWeightStart, let endW = bodyWeightEnd, bodyWeightChange != nil {
                HStack(spacing: 12) {
                    Label(weightUnit.formatShort(startW), systemImage: "scalemass")
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    Text(weightUnit.formatShort(endW))
                    if let change = bodyWeightChange {
                        Text("(\(change > 0 ? "+" : "")\(weightUnit.formatShort(abs(change))))")
                            .foregroundStyle(change > 0 ? .red : .green)
                    }
                    Spacer()
                }
                .font(.caption).padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if avgSteps != nil || avgSleepMinutes != nil || avgRestingHR != nil || avgHRV != nil {
                HStack(spacing: 16) {
                    if let steps = avgSteps { Label(HealthFormatters.formatSteps(steps), systemImage: "figure.walk") }
                    if let sleep = avgSleepMinutes { Label(HealthFormatters.formatSleepShort(sleep), systemImage: "bed.double.fill") }
                    if let hr = avgRestingHR { Label("\(Int(hr))bpm", systemImage: "heart.fill") }
                    if let hrv = avgHRV { Label("\(Int(hrv))ms", systemImage: "waveform.path.ecg") }
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            HStack {
                Image(systemName: "dumbbell.fill").font(.caption)
                Text("Metricly").font(.caption.bold())
                Spacer()
                if currentStreak > 0 {
                    Text("\(currentStreak) day streak").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func shareStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 { return String(format: "%.1fk %@", volume / 1000, weightUnit.label) }
        return String(format: "%.0f %@", volume, weightUnit.label)
    }
}

#Preview {
    NavigationStack { WeeklyMonthlyReportView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
