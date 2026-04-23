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

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var goalMl: Double {
        Double(settings.dailyWaterGoalMl)
    }

    // MARK: - Today

    private var todayEntries: [WaterEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return allEntries.filter { $0.date >= start }
    }

    private var todayTotalMl: Double {
        todayEntries.reduce(0) { $0 + $1.milliliters }
    }

    private var progress: Double {
        min(1.0, todayTotalMl / goalMl)
    }

    // MARK: - Daily Totals

    private var dayCount: Int {
        timeRange == .week ? 7 : 30
    }

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

    // MARK: - Weekly Stats

    private func weeklyStats(days: Int) -> (avg: Double, daysMetGoal: Int, totalDays: Int) {
        let totals = dailyTotals(days: days)
        guard !totals.isEmpty else { return (0, 0, 0) }
        let nonZeroDays = totals.filter { $0.ml > 0 }
        let avg = nonZeroDays.isEmpty ? 0 : nonZeroDays.map(\.ml).reduce(0, +) / Double(nonZeroDays.count)
        let metGoal = totals.filter { $0.ml >= goalMl }.count
        return (avg, metGoal, totals.count)
    }

    // MARK: - Hydration Streak

    private var hydrationStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        // If today's goal not yet met, start from yesterday
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
            } else {
                break
            }
        }
        return streak
    }

    // MARK: - Time-of-Day Breakdown

    private struct TimeBlock: Identifiable {
        let id = UUID()
        let label: String
        let icon: String
        let ml: Double
        let color: Color
    }

    private var timeOfDayBreakdown: [TimeBlock] {
        let calendar = Calendar.current
        var morning: Double = 0
        var afternoon: Double = 0
        var evening: Double = 0
        var night: Double = 0

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
        List {
            progressSection
            quickAddSection
            statsRow
            if hydrationStreak > 0 || todayTotalMl >= goalMl {
                streakSection
            }
            if !todayEntries.isEmpty {
                timeOfDaySection
            }
            chartSection
            todayEntriesSection
        }
        .navigationTitle("Water Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMlFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if undoEntry != nil {
                undoBar
            }
        }
    }

    // MARK: - Section: Progress Ring

    private var progressSection: some View {
        Section {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .stroke(.quaternary, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.cyan.gradient,
                                style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)
                    VStack(spacing: 2) {
                        Text("\(Int(todayTotalMl))")
                            .font(.title.bold().monospacedDigit())
                        Text("/ \(Int(goalMl)) ml")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 120, height: 120)

                if progress >= 1.0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Goal reached!")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.green.opacity(0.1), in: Capsule())
                } else {
                    Text("\(Int(goalMl - todayTotalMl)) ml remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section: Quick Add

    private var quickAddSection: some View {
        Section("Log Water") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WaterEntry.presets, id: \.label) { preset in
                        Button {
                            addEntry(ml: preset.ml)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.system(size: 18))
                                    .foregroundStyle(.cyan)
                                Text(preset.label)
                                    .font(.caption2)
                                Text("\(Int(preset.ml)) ml")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 80, height: 65)
                            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            HStack {
                Text("Custom")
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("ml", text: $customMl)
                    .keyboardType(.numberPad)
                    .focused($isMlFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
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
                }
                .disabled(Double(customMl) ?? 0 <= 0)
            }
        }
    }

    // MARK: - Section: Stats Row

    private var statsRow: some View {
        Section {
            let stats = weeklyStats(days: dayCount)
            HStack {
                VStack(spacing: 4) {
                    Text("\(Int(stats.avg))")
                        .font(.title3.bold().monospacedDigit())
                    Text("Avg ml/day")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 4) {
                    Text("\(stats.daysMetGoal)/\(stats.totalDays)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(stats.daysMetGoal > stats.totalDays / 2 ? .green : .primary)
                    Text("Days at Goal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 4) {
                    Text("\(hydrationStreak)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(hydrationStreak >= 3 ? .cyan : .primary)
                    Text("Day Streak")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        } header: {
            Text("Stats (\(timeRange.rawValue))")
        }
    }

    // MARK: - Section: Streak

    private var streakSection: some View {
        Section {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: hydrationStreak >= 7 ? "drop.circle.fill" : "drop.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }
                VStack(alignment: .leading, spacing: 2) {
                    if hydrationStreak > 0 {
                        Text("\(hydrationStreak)-day hydration streak!")
                            .font(.subheadline.weight(.semibold))
                        Text("Keep hitting your daily goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if todayTotalMl >= goalMl {
                        Text("Goal met today!")
                            .font(.subheadline.weight(.semibold))
                        Text("Start a streak by hitting your goal again tomorrow")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }
        }
    }

    // MARK: - Section: Time of Day

    private var timeOfDaySection: some View {
        Section("Hydration by Time of Day") {
            HStack(spacing: 8) {
                ForEach(timeOfDayBreakdown) { block in
                    VStack(spacing: 6) {
                        Image(systemName: block.icon)
                            .font(.caption)
                            .foregroundStyle(block.color)
                        Text("\(Int(block.ml))")
                            .font(.system(.caption, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Text("ml")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text(block.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(block.ml > 0 ? block.color.opacity(0.08) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Section: Chart

    private var chartSection: some View {
        Section {
            Picker("Range", selection: $timeRange) {
                ForEach(TimeRange.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .listRowSeparator(.hidden)

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
                            Text("\(Int(goalMl))")
                                .font(.system(size: 9))
                                .foregroundStyle(.cyan)
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
                .padding(.vertical, 8)
            }
        } header: {
            Text("History")
        }
    }

    // MARK: - Section: Today's Entries

    private var todayEntriesSection: some View {
        Section("Today's Entries") {
            if todayEntries.isEmpty {
                Text("No water logged today.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(todayEntries) { entry in
                    HStack {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(.cyan)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(Int(entry.milliliters)) ml")
                                .font(.subheadline.weight(.semibold))
                            Text(entry.date, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { offsets in
                    for index in offsets {
                        modelContext.delete(todayEntries[index])
                    }
                }
            }
        }
    }

    // MARK: - Undo Bar

    private var undoBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill")
                .foregroundStyle(.cyan)
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
            .font(.subheadline.bold())
            .foregroundStyle(.cyan)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func addEntry(ml: Double) {
        let entry = WaterEntry(milliliters: ml)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        // Undo support
        undoWorkItem?.cancel()
        withAnimation(.spring(duration: 0.3)) {
            undoEntry = entry
        }
        let work = DispatchWorkItem {
            withAnimation(.spring(duration: 0.3)) {
                undoEntry = nil
            }
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }
}

#Preview {
    NavigationStack {
        WaterTrackerView()
    }
    .modelContainer(for: [WaterEntry.self, UserSettings.self], inMemory: true)
}
