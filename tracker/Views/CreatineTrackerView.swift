import SwiftUI
import SwiftData
import Charts

struct CreatineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreatineEntry.date, order: .reverse) private var entries: [CreatineEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var undoEntry: CreatineEntry?
    @State private var undoWorkItem: DispatchWorkItem?

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var dose: Double {
        settings.creatineLoadingPhase ? 5.0 : settings.creatineDailyDose
    }

    private var isLoadingPhase: Bool {
        settings.creatineLoadingPhase
    }

    private var loadingDosesPerDay: Int { 4 }

    private var dailyTargetGrams: Double {
        isLoadingPhase ? 20.0 : settings.creatineDailyDose
    }

    // MARK: - Today

    private var todayEntries: [CreatineEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return entries.filter { $0.date >= start }
    }

    private var todayTotalGrams: Double {
        todayEntries.reduce(0) { $0 + $1.grams }
    }

    private var hasTakenToday: Bool {
        !todayEntries.isEmpty
    }

    private var todayComplete: Bool {
        todayTotalGrams >= dailyTargetGrams
    }

    private var dosesRemainingToday: Int {
        if isLoadingPhase {
            return max(0, loadingDosesPerDay - todayEntries.count)
        }
        return todayComplete ? 0 : 1
    }

    // MARK: - Streaks

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: .now)

        if !hasTakenToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let dayStart = checkDate
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            if entries.contains(where: { $0.date >= dayStart && $0.date < dayEnd }) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = prev
            } else {
                break
            }
        }
        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let sortedDates = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard !sortedDates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Weekly Compliance

    private var weeklyCompliance: (taken: Int, total: Int, percentage: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var taken = 0
        let total = 7

        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayStart = date
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }
            if entries.contains(where: { $0.date >= dayStart && $0.date < dayEnd }) {
                taken += 1
            }
        }

        let pct = total > 0 ? Double(taken) / Double(total) * 100 : 0
        return (taken, total, pct)
    }

    // MARK: - Calendar Data

    private var last28Days: [(date: Date, taken: Bool, grams: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<28).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let dayEntries = entries.filter { $0.date >= date && $0.date < nextDay }
            let grams = dayEntries.reduce(0) { $0 + $1.grams }
            return (date: date, taken: !dayEntries.isEmpty, grams: grams)
        }
    }

    // MARK: - Monthly Chart Data

    private var last30DailyGrams: [(date: Date, grams: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return (0..<30).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: date) else { return nil }
            let grams = entries.filter { $0.date >= date && $0.date < nextDay }.reduce(0) { $0 + $1.grams }
            return (date: date, grams: grams)
        }
    }

    // MARK: - Body

    var body: some View {
        List {
            todaySection
            if isLoadingPhase {
                loadingPhaseSection
            }
            streakSection
            complianceSection
            calendarSection
            chartSection
            recentHistorySection
        }
        .navigationTitle("Creatine Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if undoEntry != nil {
                undoBar
            }
        }
    }

    // MARK: - Section: Today's Status

    private var todaySection: some View {
        Section {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(todayComplete ? Color.green.opacity(0.15) : hasTakenToday ? Color.blue.opacity(0.15) : Color(.systemGray5))
                        .frame(width: 100, height: 100)
                    if todayComplete {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.green)
                    } else if isLoadingPhase {
                        VStack(spacing: 2) {
                            Text("\(todayEntries.count)/\(loadingDosesPerDay)")
                                .font(.title2.bold().monospacedDigit())
                            Text("doses")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Image(systemName: hasTakenToday ? "checkmark.circle.fill" : "pill.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(hasTakenToday ? .green : .secondary)
                    }
                }

                if todayComplete {
                    Text(isLoadingPhase ? "All doses taken today" : "Taken today")
                        .font(.headline)
                        .foregroundStyle(.green)
                } else if isLoadingPhase && hasTakenToday {
                    Text("\(dosesRemainingToday) dose\(dosesRemainingToday == 1 ? "" : "s") remaining")
                        .font(.headline)
                        .foregroundStyle(.blue)
                } else {
                    Text(hasTakenToday ? "Taken today" : "Not taken yet")
                        .font(.headline)
                        .foregroundStyle(hasTakenToday ? .green : .secondary)
                }

                if !todayComplete {
                    Button {
                        logCreatine()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Log \(String(format: "%.0f", dose))g Creatine")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }

                if isLoadingPhase {
                    Text("Loading Phase — \(String(format: "%.0f", todayTotalGrams))g of \(String(format: "%.0f", dailyTargetGrams))g today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section: Loading Phase

    private var loadingPhaseSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.yellow)
                    Text("Loading Phase Active")
                        .font(.subheadline.weight(.semibold))
                }

                Text("Take \(String(format: "%.0f", dose))g × \(loadingDosesPerDay) times/day (20g total) to saturate your muscles quickly. Typically lasts 5–7 days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Progress for today's doses
                HStack(spacing: 6) {
                    ForEach(0..<loadingDosesPerDay, id: \.self) { index in
                        Circle()
                            .fill(index < todayEntries.count ? Color.blue : Color(.systemGray4))
                            .frame(width: 20, height: 20)
                            .overlay {
                                if index < todayEntries.count {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    Spacer()
                    Text("\(todayEntries.count)/\(loadingDosesPerDay)")
                        .font(.caption.bold().monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Section: Streak

    private var streakSection: some View {
        Section("Streak") {
            HStack {
                VStack(spacing: 4) {
                    Text("\(currentStreak)")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(currentStreak >= 7 ? .blue : .primary)
                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 4) {
                    Text("\(longestStreak)")
                        .font(.title.bold().monospacedDigit())
                        .foregroundStyle(.blue)
                    Text("Longest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Divider().frame(height: 36)

                VStack(spacing: 4) {
                    Text("\(entries.count)")
                        .font(.title.bold().monospacedDigit())
                    Text("Total Days")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section: Weekly Compliance

    private var complianceSection: some View {
        Section {
            let compliance = weeklyCompliance
            VStack(spacing: 10) {
                HStack {
                    Text("Weekly Compliance")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(Int(compliance.percentage))%")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(compliance.percentage >= 85 ? .green : compliance.percentage >= 50 ? .orange : .red)
                }

                ProgressView(value: compliance.percentage, total: 100)
                    .tint(compliance.percentage >= 85 ? .green : compliance.percentage >= 50 ? .orange : .red)

                HStack {
                    Text("\(compliance.taken)/\(compliance.total) days this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if compliance.percentage >= 85 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .font(.caption2)
                            Text("Consistent")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Section: Calendar Grid

    private var calendarSection: some View {
        Section("Last 28 Days") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(last28Days, id: \.date) { day in
                    VStack(spacing: 2) {
                        Text(day.date, format: .dateTime.day())
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(day.taken ? Color.blue : Color(.systemGray5))
                            .frame(width: 24, height: 24)
                            .overlay {
                                if day.taken {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Section: 30-Day Chart

    private var chartSection: some View {
        Section("30-Day Intake") {
            let data = last30DailyGrams
            if !data.isEmpty {
                Chart(data, id: \.date) { day in
                    BarMark(
                        x: .value("Day", day.date, unit: .day),
                        y: .value("g", day.grams)
                    )
                    .foregroundStyle(day.grams >= dailyTargetGrams ? Color.blue : day.grams > 0 ? Color.blue.opacity(0.4) : Color.clear)
                    .cornerRadius(3)

                    RuleMark(y: .value("Target", dailyTargetGrams))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                        .foregroundStyle(.blue.opacity(0.4))
                }
                .chartYAxisLabel("grams")
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 160)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Section: Recent History

    private var recentHistorySection: some View {
        Section("Recent History") {
            if entries.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(entries.prefix(14)) { entry in
                    HStack {
                        Image(systemName: "pill.fill")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(String(format: "%.0f", entry.grams))g creatine")
                                .font(.subheadline.weight(.semibold))
                            Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
                .onDelete { offsets in
                    let prefixed = Array(entries.prefix(14))
                    for index in offsets {
                        modelContext.delete(prefixed[index])
                    }
                }
            }
        }
    }

    // MARK: - Undo Bar

    private var undoBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "pill.fill")
                .foregroundStyle(.blue)
            Text("Logged \(String(format: "%.0f", undoEntry?.grams ?? 0))g creatine")
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
            .foregroundStyle(.blue)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func logCreatine() {
        let entry = CreatineEntry(grams: dose)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

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
        CreatineTrackerView()
    }
    .modelContainer(for: [CreatineEntry.self, UserSettings.self], inMemory: true)
}
