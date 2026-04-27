import SwiftUI
import SwiftData
import Charts

struct WaterTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WaterEntry.date, order: .reverse) private var allEntries: [WaterEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var customMl = ""
    @FocusState private var isMlFocused: Bool
    @State private var timeRange: TimeRange = .week
    @State private var undoEntry: WaterEntry?
    @State private var undoWorkItem: DispatchWorkItem?

    private enum TimeRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
    }

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var goalMl: Double { Double(settings.dailyWaterGoalMl) }

    private var todayEntries: [WaterEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= start }
    }

    private var todayTotalMl: Double { todayEntries.reduce(0) { $0 + $1.milliliters } }
    private var progress: Double { min(1.0, todayTotalMl / goalMl) }
    private var dayCount: Int { timeRange == .week ? 7 : 30 }

    private func dailyTotals(days: Int) -> [(date: Date, ml: Double)] {
        let calendar = Calendar.current
        return (0..<days).reversed().compactMap { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: .now) else { return nil }
            let start = calendar.startOfDay(for: date)
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return nil }
            let total = allEntries.filter { $0.date >= start && $0.date < end }.reduce(0) { $0 + $1.milliliters }
            return (date: start, ml: total)
        }
    }

    private func weeklyStats(days: Int) -> (avg: Double, daysMetGoal: Int, totalDays: Int) {
        let totals = dailyTotals(days: days)
        guard !totals.isEmpty else { return (0, 0, 0) }
        let nonZeroDays = totals.filter { $0.ml > 0 }
        let avg = nonZeroDays.isEmpty ? 0 : nonZeroDays.map(\.ml).reduce(0, +) / Double(nonZeroDays.count)
        let metGoal = totals.filter { $0.ml >= goalMl }.count
        return (avg, metGoal, totals.count)
    }

    private var hydrationStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)
        if todayTotalMl < goalMl {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }
        while true {
            let dayStart = checkDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            let dayTotal = allEntries.filter { $0.date >= dayStart && $0.date < dayEnd }.reduce(0) { $0 + $1.milliliters }
            if dayTotal >= goalMl {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else { break }
        }
        return streak
    }

    private struct TimeBlock: Identifiable {
        let id = UUID(); let label: String; let icon: String; let ml: Double; let color: Color
    }

    private var timeOfDayBreakdown: [TimeBlock] {
        let calendar = Calendar.current
        var morning: Double = 0, afternoon: Double = 0, evening: Double = 0, night: Double = 0
        for entry in todayEntries {
            let hour = calendar.component(.hour, from: entry.date)
            switch hour {
            case 5..<12: morning += entry.milliliters
            case 12..<17: afternoon += entry.milliliters
            case 17..<21: evening += entry.milliliters
            default: night += entry.milliliters
            }
        }
        return [
            TimeBlock(label: "Morning", icon: "sunrise.fill", ml: morning, color: .orange),
            TimeBlock(label: "Afternoon", icon: "sun.max.fill", ml: afternoon, color: .yellow),
            TimeBlock(label: "Evening", icon: "sunset.fill", ml: evening, color: .indigo),
            TimeBlock(label: "Night", icon: "moon.fill", ml: night, color: .purple),
        ]
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                quickAddCard
                statsCard
                if hydrationStreak > 0 || todayTotalMl >= goalMl {
                    streakCard
                }
                if !todayEntries.isEmpty {
                    timeOfDayCard
                }
                chartCard
                if !todayEntries.isEmpty {
                    todayLogCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Water")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMlFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if undoEntry != nil { undoBar }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.cyan, Color(red: 0.0, green: 0.75, blue: 0.85).opacity(0.75)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 200)
                .offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.25), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.6), value: progress)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(Int(todayTotalMl))")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("ml")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Text("of \(Int(goalMl)) ml goal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                if progress >= 1.0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.caption.bold())
                        Text("Goal Reached!")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 5)
                    .background(.white.opacity(0.20), in: Capsule())
                } else {
                    Text("\(Int(goalMl - todayTotalMl)) ml remaining")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.80))
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(.white.opacity(0.15), in: Capsule())
                }

                GradientProgressBar(value: progress, color: .white, height: 6)
                    .opacity(0.7)
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Quick Add Card

    private var quickAddCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Water", icon: "drop.fill", color: .cyan)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WaterEntry.presets, id: \.label) { preset in
                        Button { addEntry(ml: preset.ml) } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.12))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: preset.icon)
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(.cyan)
                                }
                                Text(preset.label)
                                    .font(.caption2.weight(.medium))
                                Text("\(Int(preset.ml)) ml")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.10))
                        .frame(width: 36, height: 36)
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.cyan)
                }
                TextField("Custom amount", text: $customMl)
                    .keyboardType(.numberPad)
                    .focused($isMlFocused)
                Text("ml")
                    .foregroundStyle(.secondary)
                Button {
                    if let ml = Double(customMl), ml > 0 {
                        addEntry(ml: ml)
                        customMl = ""
                        isMlFocused = false
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }
                .disabled(Double(customMl) ?? 0 <= 0)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            let stats = weeklyStats(days: dayCount)
            SectionHeader(title: "Stats (\(timeRange.rawValue))", icon: "chart.bar.fill", color: .cyan)

            HStack(spacing: 0) {
                statColumn(value: "\(Int(stats.avg))", label: "Avg ml/day", color: .cyan)
                Divider().frame(height: 44)
                statColumn(
                    value: "\(stats.daysMetGoal)/\(stats.totalDays)",
                    label: "Days at Goal",
                    color: stats.daysMetGoal > stats.totalDays / 2 ? .green : .primary
                )
                Divider().frame(height: 44)
                statColumn(
                    value: "\(hydrationStreak)",
                    label: "Day Streak",
                    color: hydrationStreak >= 3 ? .cyan : .primary
                )
            }
        }
        .appCard()
    }

    private func statColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: hydrationStreak >= 7 ? "drop.circle.fill" : "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
            }
            VStack(alignment: .leading, spacing: 3) {
                if hydrationStreak > 0 {
                    Text("\(hydrationStreak)-day hydration streak!")
                        .font(.subheadline.weight(.semibold))
                    Text("Keep hitting your daily goal")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Goal met today!")
                        .font(.subheadline.weight(.semibold))
                    Text("Start a streak by hitting your goal again tomorrow")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .appCard()
    }

    // MARK: - Time of Day Card

    private var timeOfDayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Hydration by Time of Day", icon: "clock.fill", color: .cyan)

            HStack(spacing: 8) {
                ForEach(timeOfDayBreakdown) { block in
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(block.ml > 0 ? block.color.opacity(0.12) : Color(.systemFill))
                                .frame(width: 36, height: 36)
                            Image(systemName: block.icon)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(block.ml > 0 ? block.color : .secondary)
                        }
                        Text("\(Int(block.ml))")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .monospacedDigit()
                        Text("ml")
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                        Text(block.label)
                            .font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(block.ml > 0 ? block.color.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .appCard()
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "chart.bar.fill", color: .cyan)

            HStack(spacing: 6) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { timeRange = range }
                    } label: {
                        Text(range.rawValue)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(timeRange == range ? .white : .primary)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(
                                timeRange == range
                                    ? AnyShapeStyle(Color.cyan)
                                    : AnyShapeStyle(Color(.tertiarySystemGroupedBackground)),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            let totals = dailyTotals(days: dayCount)
            if !totals.isEmpty {
                Chart(totals, id: \.date) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("ml", day.ml)
                    )
                    .foregroundStyle(day.ml >= goalMl ? Color.cyan : Color.cyan.opacity(0.4))
                    .cornerRadius(4)

                    RuleMark(y: .value("Goal", goalMl))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.cyan.opacity(0.5))
                        .annotation(position: .trailing, alignment: .leading) {
                            Text("\(Int(goalMl))").font(.system(size: 9)).foregroundStyle(.cyan)
                        }
                }
                .chartYAxisLabel("ml")
                .chartXAxis {
                    if timeRange == .week {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                        }
                    } else {
                        AxisMarks(values: .stride(by: .day, count: 5)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                }
                .frame(height: 180)
            }
        }
        .appCard()
    }

    // MARK: - Today Log Card

    private var todayLogCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today's Entries", icon: "list.bullet", color: .secondary)

            VStack(spacing: 0) {
                ForEach(Array(todayEntries.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.cyan.opacity(0.12)).frame(width: 32, height: 32)
                            Image(systemName: "drop.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.cyan)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(entry.milliliters)) ml")
                                .font(.subheadline.weight(.semibold))
                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if idx < todayEntries.count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Undo Bar

    private var undoBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill").foregroundStyle(.cyan)
            Text("Added \(Int(undoEntry?.milliliters ?? 0)) ml")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Undo") {
                if let entry = undoEntry {
                    modelContext.delete(entry)
                    undoWorkItem?.cancel()
                    undoEntry = nil
                }
            }
            .font(.subheadline.bold()).foregroundStyle(.cyan)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func addEntry(ml: Double) {
        let entry = WaterEntry(milliliters: ml)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        undoWorkItem?.cancel()
        withAnimation(.spring(duration: 0.3)) { undoEntry = entry }
        let work = DispatchWorkItem {
            withAnimation(.spring(duration: 0.3)) { undoEntry = nil }
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

#Preview {
    NavigationStack { WaterTrackerView() }
        .modelContainer(for: [WaterEntry.self, UserSettings.self], inMemory: true)
}
