import SwiftUI
import SwiftData
import HealthKit

enum ReportPeriod: String, CaseIterable {
    case week = "This Week"
    case month = "This Month"
}

struct WeeklyMonthlyReportView: View {
    // MARK: - Data Queries
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]

    @Query(sort: \BodyWeightEntry.date) private var allBodyWeightEntries: [BodyWeightEntry]

    @Query private var settingsArray: [UserSettings]

    // MARK: - Environment
    @Environment(\.weightUnit) private var weightUnit

    // MARK: - State
    @State private var selectedPeriod: ReportPeriod = .week
    @State private var showingShare = false
    @State private var shareImage: UIImage?

    // MARK: - HealthKit State
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
        let calendar = Calendar.current
        let now = Date.now
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
        let calendar = Calendar.current
        let current = currentPeriodRange
        switch selectedPeriod {
        case .week:
            let prevStart = calendar.date(byAdding: .day, value: -7, to: current.start)!
            return (prevStart, current.start)
        case .month:
            let prevMonthStart = calendar.date(byAdding: .month, value: -1, to: current.start)!
            return (prevMonthStart, current.start)
        }
    }

    // MARK: - Filtered Workouts

    private var periodWorkouts: [Workout] {
        let range = currentPeriodRange
        return allWorkouts.filter { $0.date >= range.start && $0.date <= range.end }
    }

    private var previousPeriodWorkouts: [Workout] {
        let range = previousPeriodRange
        return allWorkouts.filter { $0.date >= range.start && $0.date < range.end }
    }

    private var workoutsBeforePeriod: [Workout] {
        let range = currentPeriodRange
        return allWorkouts.filter { $0.date < range.start }
    }

    // MARK: - Training Summary

    private var workoutCount: Int { periodWorkouts.count }

    private var totalSets: Int {
        periodWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
        }
    }

    private var totalVolumeKg: Double {
        periodWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
    }

    private var totalVolume: Double {
        weightUnit == .kg ? totalVolumeKg : totalVolumeKg * 2.20462
    }

    private var totalDuration: TimeInterval {
        periodWorkouts.reduce(0) { $0 + ($1.duration ?? 0) }
    }

    private var formattedDuration: String {
        let totalMinutes = Int(totalDuration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
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

    // MARK: - PRs

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
                    prNames.append(exercise.name)
                    historicalMax[key] = maxWeight
                }
            }
        }
        return prNames
    }

    private var prsHitCount: Int { prExerciseNames.count }

    // MARK: - Muscle Groups

    private var muscleGroupSetCounts: [(group: MuscleGroup, sets: Int)] {
        var counts: [MuscleGroup: Int] = [:]
        for workout in periodWorkouts {
            for exercise in workout.exercises {
                if let group = exercise.category {
                    let workingSets = exercise.sets.filter { !$0.isWarmUp }.count
                    counts[group, default: 0] += workingSets
                }
            }
        }
        return counts.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    // MARK: - Body Weight

    private var periodBodyWeightEntries: [BodyWeightEntry] {
        let range = currentPeriodRange
        return allBodyWeightEntries.filter { $0.date >= range.start && $0.date <= range.end }
            .sorted { $0.date < $1.date }
    }

    private var bodyWeightStart: Double? { periodBodyWeightEntries.first?.weight }
    private var bodyWeightEnd: Double? { periodBodyWeightEntries.last?.weight }

    private var bodyWeightChange: Double? {
        guard let start = bodyWeightStart, let end = bodyWeightEnd, periodBodyWeightEntries.count >= 2 else { return nil }
        let diff = end - start
        guard abs(diff) > 0.01 else { return nil }
        return diff
    }

    // MARK: - Consistency

    private var currentStreak: Int {
        let calendar = Calendar.current
        let workoutDays = Set(allWorkouts.map { calendar.startOfDay(for: $0.date) })
        guard !workoutDays.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)
        if !workoutDays.contains(checkDate) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while workoutDays.contains(checkDate) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
            checkDate = prev
        }
        return streak
    }

    private var workoutsPerWeekAverage: Double? {
        guard selectedPeriod == .month, !periodWorkouts.isEmpty else { return nil }
        let calendar = Calendar.current
        let range = currentPeriodRange
        let daysPassed = max(1, calendar.dateComponents([.day], from: range.start, to: range.end).day ?? 1)
        let weeks = max(1.0, Double(daysPassed) / 7.0)
        return Double(periodWorkouts.count) / weeks
    }

    private var bestDay: String? {
        guard !periodWorkouts.isEmpty else { return nil }
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        for workout in periodWorkouts {
            let weekday = calendar.component(.weekday, from: workout.date)
            dayCounts[weekday, default: 0] += 1
        }
        guard let bestWeekday = dayCounts.max(by: { $0.value < $1.value })?.key else { return nil }
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[bestWeekday - 1]
    }

    // MARK: - Header

    private var periodLabel: String {
        let formatter = DateFormatter()
        let range = currentPeriodRange
        switch selectedPeriod {
        case .week:
            formatter.dateFormat = "MMM d"
            let calendar = Calendar.current
            let endOfWeek = calendar.date(byAdding: .day, value: 6, to: range.start)!
            let displayEnd = min(endOfWeek, Date.now)
            return "\(formatter.string(from: range.start)) – \(formatter.string(from: displayEnd))"
        case .month:
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: range.start)
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

    private var healthKitEnabled: Bool {
        settingsArray.first?.healthKitEnabled ?? false
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Picker("Period", selection: $selectedPeriod) {
                    ForEach(ReportPeriod.allCases, id: \.self) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                headerSection

                if periodWorkouts.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts", systemImage: "figure.walk")
                    } description: {
                        Text("No workouts logged \(selectedPeriod == .week ? "this week" : "this month") yet.")
                    }
                    .padding(.top, 40)
                } else {
                    trainingSummarySection
                    prsSection
                    muscleGroupsSection
                    bodyWeightSection
                    if healthKitEnabled {
                        healthSummarySection
                    }
                    consistencySection
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    shareAsImage()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .disabled(periodWorkouts.isEmpty)
            }
        }
        .sheet(isPresented: $showingShare) {
            if let image = shareImage {
                ShareSheet(items: [image])
            }
        }
        .task(id: selectedPeriod) {
            guard healthKitEnabled else { return }
            await loadHealthData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            avgSteps = nil
            avgSleepMinutes = nil
            avgRestingHR = nil
            avgHRV = nil
            prevAvgSteps = nil
            prevAvgSleepMinutes = nil
            prevAvgRestingHR = nil
            prevAvgHRV = nil
        }
    }

    // MARK: - Section Views

    private var headerSection: some View {
        VStack(spacing: 4) {
            Text(vibeEmoji)
                .font(.system(size: 40))
            Text(selectedPeriod == .week ? "Weekly Report" : "Monthly Report")
                .font(.title2.bold())
            Text(periodLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var trainingSummarySection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            statCard(icon: "figure.strengthtraining.traditional", value: "\(workoutCount)", label: "Workouts", color: .blue)
            statCard(icon: "clock", value: formattedDuration, label: "Total Time", color: .green)
            statCard(icon: "scalemass", value: formatVolume(totalVolume), label: "Volume", color: .purple, change: volumeChange)
            statCard(icon: "number", value: "\(totalSets)", label: "Sets", color: .orange)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var prsSection: some View {
        if prsHitCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundStyle(.yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(prsHitCount) Personal Record\(prsHitCount == 1 ? "" : "s")")
                            .font(.headline)
                        Text(prExerciseNames.joined(separator: ", "))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var muscleGroupsSection: some View {
        if !muscleGroupSetCounts.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Muscle Groups Trained")
                    .font(.headline)
                FlowLayout(spacing: 8) {
                    ForEach(muscleGroupSetCounts, id: \.group) { item in
                        HStack(spacing: 4) {
                            Image(systemName: item.group.icon)
                            Text("\(item.group.rawValue) (\(item.sets))")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemFill), in: Capsule())
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var bodyWeightSection: some View {
        if let startW = bodyWeightStart, let endW = bodyWeightEnd, periodBodyWeightEntries.count >= 2 {
            VStack(alignment: .leading, spacing: 8) {
                Text("Body Weight")
                    .font(.headline)
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(weightUnit.format(startW))
                            .font(.title3.bold().monospacedDigit())
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Latest")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(weightUnit.format(endW))
                            .font(.title3.bold().monospacedDigit())
                    }
                    if let change = bodyWeightChange {
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Change")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 2) {
                                Image(systemName: change > 0 ? "arrow.up.right" : "arrow.down.right")
                                    .imageScale(.small)
                                Text(weightUnit.format(abs(change)))
                            }
                            .font(.subheadline.bold())
                            .foregroundStyle(change > 0 ? .red : .green)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }

    @ViewBuilder
    private var healthSummarySection: some View {
        if avgSteps != nil || avgSleepMinutes != nil || avgRestingHR != nil || avgHRV != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("Health Summary")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if let steps = avgSteps {
                        healthStatCard(icon: "figure.walk", value: HealthFormatters.formatSteps(steps), label: "Avg Steps", color: .green, current: steps, previous: prevAvgSteps, higherIsBetter: true)
                    }
                    if let sleep = avgSleepMinutes {
                        healthStatCard(icon: "bed.double.fill", value: HealthFormatters.formatSleepShort(sleep), label: "Avg Sleep", color: .indigo, current: sleep, previous: prevAvgSleepMinutes, higherIsBetter: true)
                    }
                    if let hr = avgRestingHR {
                        healthStatCard(icon: "heart.fill", value: "\(Int(hr)) bpm", label: "Avg Resting HR", color: .red, current: hr, previous: prevAvgRestingHR, higherIsBetter: false)
                    }
                    if let hrv = avgHRV {
                        healthStatCard(icon: "waveform.path.ecg", value: "\(Int(hrv)) ms", label: "Avg HRV", color: .purple, current: hrv, previous: prevAvgHRV, higherIsBetter: true)
                    }
                }
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        } else if isLoadingHealth {
            ProgressView("Loading health data...")
                .padding()
        }
    }

    private var consistencySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consistency")
                .font(.headline)
            HStack(spacing: 0) {
                consistencyStat(icon: "flame.fill", value: "\(currentStreak)", label: "Day Streak", color: .orange)
                if let wpw = workoutsPerWeekAverage {
                    Divider().frame(height: 36)
                    consistencyStat(icon: "chart.bar", value: String(format: "%.1f", wpw), label: "Per Week", color: .blue)
                }
                if let best = bestDay {
                    Divider().frame(height: 36)
                    consistencyStat(icon: "star", value: best, label: "Best Day", color: .yellow)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    // MARK: - Helper Views

    private func statCard(icon: String, value: String, label: String, color: Color, change: Double? = nil) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .imageScale(.small)
                    Text(String(format: "%+.0f%%", change))
                }
                .font(.caption2.bold())
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func healthStatCard(icon: String, value: String, label: String, color: Color, current: Double, previous: Double?, higherIsBetter: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.headline.monospacedDigit())
            HStack(spacing: 2) {
                Text(label)
                if let trend = trendInfo(current: current, previous: previous, higherIsBetter: higherIsBetter) {
                    Image(systemName: trend.icon)
                        .imageScale(.small)
                        .foregroundStyle(trend.isGood ? .green : .red)
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }

    private func consistencyStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Trend Helper

    private func trendInfo(current: Double, previous: Double?, higherIsBetter: Bool) -> (icon: String, isGood: Bool)? {
        guard let prev = previous, prev > 0 else { return nil }
        let diff = current - prev
        guard abs(diff / prev) > 0.02 else { return nil }
        let goingUp = diff > 0
        let isGood = goingUp == higherIsBetter
        return (goingUp ? "arrow.up.right" : "arrow.down.right", isGood)
    }

    // MARK: - HealthKit Loading

    private func loadHealthData() async {
        isLoadingHealth = true
        defer { isLoadingHealth = false }

        let hk = HealthKitManager.shared
        let days: Int = selectedPeriod == .week ? 14 : 60

        let range = currentPeriodRange
        let prevRange = previousPeriodRange

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
            periodLabel: periodLabel,
            selectedPeriod: selectedPeriod,
            vibeEmoji: vibeEmoji,
            workoutCount: workoutCount,
            totalSets: totalSets,
            totalVolume: totalVolume,
            formattedDuration: formattedDuration,
            volumeChange: volumeChange,
            prsHitCount: prsHitCount,
            prExerciseNames: prExerciseNames,
            muscleGroupSetCounts: muscleGroupSetCounts,
            bodyWeightStart: bodyWeightStart,
            bodyWeightEnd: bodyWeightEnd,
            bodyWeightChange: bodyWeightChange,
            avgSteps: avgSteps,
            avgSleepMinutes: avgSleepMinutes,
            avgRestingHR: avgRestingHR,
            avgHRV: avgHRV,
            currentStreak: currentStreak,
            weightUnit: weightUnit
        )

        let renderer = ImageRenderer(content:
            shareCard
                .frame(width: 380)
                .padding(16)
                .background(Color(.systemGroupedBackground))
        )
        renderer.scale = 3.0
        if let image = renderer.uiImage {
            shareImage = image
            showingShare = true
        }
    }

    // MARK: - Formatting

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk %@", volume / 1000, weightUnit.label)
        }
        return String(format: "%.0f %@", volume, weightUnit.label)
    }
}

// MARK: - Share Card

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
            // Header
            VStack(spacing: 6) {
                Text(vibeEmoji).font(.system(size: 36))
                Text(selectedPeriod == .week ? "Weekly Report" : "Monthly Report")
                    .font(.title2.bold())
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.1))

            // Stats bar
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

            // PRs
            if prsHitCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("\(prsHitCount) PR\(prsHitCount == 1 ? "" : "s")")
                        .font(.subheadline.bold())
                    Text(prExerciseNames.prefix(3).joined(separator: ", "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Divider()
            }

            // Muscle groups
            if !muscleGroupSetCounts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(muscleGroupSetCounts.prefix(5), id: \.group) { item in
                        Text(item.group.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                    if muscleGroupSetCounts.count > 5 {
                        Text("+\(muscleGroupSetCounts.count - 5)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Divider()
            }

            // Body weight row
            if let startW = bodyWeightStart, let endW = bodyWeightEnd, bodyWeightChange != nil {
                HStack(spacing: 12) {
                    Label(weightUnit.formatShort(startW), systemImage: "scalemass")
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(weightUnit.formatShort(endW))
                    if let change = bodyWeightChange {
                        Text("(\(change > 0 ? "+" : "")\(weightUnit.formatShort(abs(change))))")
                            .foregroundStyle(change > 0 ? .red : .green)
                    }
                    Spacer()
                }
                .font(.caption)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Divider()
            }

            // Health row
            if avgSteps != nil || avgSleepMinutes != nil || avgRestingHR != nil || avgHRV != nil {
                HStack(spacing: 16) {
                    if let steps = avgSteps {
                        Label(HealthFormatters.formatSteps(steps), systemImage: "figure.walk")
                    }
                    if let sleep = avgSleepMinutes {
                        Label(HealthFormatters.formatSleepShort(sleep), systemImage: "bed.double.fill")
                    }
                    if let hr = avgRestingHR {
                        Label("\(Int(hr))bpm", systemImage: "heart.fill")
                    }
                    if let hrv = avgHRV {
                        Label("\(Int(hrv))ms", systemImage: "waveform.path.ecg")
                    }
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Divider()
            }

            // Footer
            HStack {
                Image(systemName: "dumbbell.fill")
                    .font(.caption)
                Text("Metricly")
                    .font(.caption.bold())
                Spacer()
                if currentStreak > 0 {
                    Text("\(currentStreak) day streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func shareStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk %@", volume / 1000, weightUnit.label)
        }
        return String(format: "%.0f %@", volume, weightUnit.label)
    }
}

#Preview {
    NavigationStack {
        WeeklyMonthlyReportView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
