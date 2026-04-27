import SwiftUI
import SwiftData
import Charts

struct CreatineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CreatineEntry.date, order: .reverse) private var entries: [CreatineEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var undoEntry: CreatineEntry?
    @State private var undoWorkItem: DispatchWorkItem?

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var dose: Double { settings.creatineLoadingPhase ? 5.0 : settings.creatineDailyDose }
    private var isLoadingPhase: Bool { settings.creatineLoadingPhase }
    private var loadingDosesPerDay: Int { 4 }
    private var dailyTargetGrams: Double { isLoadingPhase ? 20.0 : settings.creatineDailyDose }

    private var todayEntries: [CreatineEntry] {
        let start = Calendar.current.startOfDay(for: .now)
        return entries.filter { $0.date >= start }
    }
    private var todayTotalGrams: Double { todayEntries.reduce(0) { $0 + $1.grams } }
    private var hasTakenToday: Bool { !todayEntries.isEmpty }
    private var todayComplete: Bool { todayTotalGrams >= dailyTargetGrams }
    private var dosesRemainingToday: Int {
        if isLoadingPhase { return max(0, loadingDosesPerDay - todayEntries.count) }
        return todayComplete ? 0 : 1
    }

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
            } else { break }
        }
        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let sortedDates = Set(entries.map { calendar.startOfDay(for: $0.date) }).sorted(by: >)
        guard !sortedDates.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1]).day ?? 0
            if diff == 1 { current += 1; longest = max(longest, current) } else { current = 1 }
        }
        return longest
    }

    private var weeklyCompliance: (taken: Int, total: Int, percentage: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var taken = 0
        for offset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: date) else { continue }
            if entries.contains(where: { $0.date >= date && $0.date < dayEnd }) { taken += 1 }
        }
        let pct = Double(taken) / 7.0 * 100
        return (taken, 7, pct)
    }

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
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard
                if isLoadingPhase { loadingPhaseCard }
                streakCard
                complianceCard
                calendarCard
                chartCard
                recentHistoryCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Creatine")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if undoEntry != nil { undoBar }
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: todayComplete
                    ? [Color.green, Color(red: 0.1, green: 0.72, blue: 0.35).opacity(0.75)]
                    : [Color(red: 0.22, green: 0.45, blue: 0.95), Color.blue.opacity(0.75)],
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
                            .fill(.white.opacity(0.20))
                            .frame(width: 72, height: 72)
                        if todayComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                        } else if isLoadingPhase {
                            VStack(spacing: 1) {
                                Text("\(todayEntries.count)/\(loadingDosesPerDay)")
                                    .font(.system(size: 18, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("doses")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.75))
                            }
                        } else {
                            Image(systemName: hasTakenToday ? "checkmark.circle.fill" : "pill.fill")
                                .font(.system(size: 34, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(todayComplete
                             ? (isLoadingPhase ? "All doses taken!" : "Taken today")
                             : (hasTakenToday && isLoadingPhase
                                ? "\(dosesRemainingToday) dose\(dosesRemainingToday == 1 ? "" : "s") left"
                                : (hasTakenToday ? "Taken today" : "Not taken yet")))
                            .font(.system(size: 26, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text(isLoadingPhase
                             ? "Loading Phase — \(String(format: "%.0f", todayTotalGrams))g / \(String(format: "%.0f", dailyTargetGrams))g"
                             : "\(String(format: "%.0f", dose))g daily dose")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.75))
                    }
                }

                if !todayComplete {
                    Button { logCreatine() } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.subheadline.bold())
                            Text("Log \(String(format: "%.0f", dose))g Creatine")
                                .font(.subheadline.bold())
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .heroCard()
    }

    // MARK: - Loading Phase Card

    private var loadingPhaseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.yellow.opacity(0.15)).frame(width: 36, height: 36)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.yellow)
                }
                Text("Loading Phase Active")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }

            Text("Take \(String(format: "%.0f", dose))g × \(loadingDosesPerDay) times/day (20g total) to saturate your muscles quickly. Typically lasts 5–7 days.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(0..<loadingDosesPerDay, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index < todayEntries.count ? Color.blue : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        if index < todayEntries.count {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
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
        .appCard()
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Streak", icon: "flame.fill", color: .orange)

            HStack(spacing: 0) {
                streakColumn(value: "\(currentStreak)", label: "Current", color: currentStreak >= 7 ? .blue : .primary)
                Divider().frame(height: 44)
                streakColumn(value: "\(longestStreak)", label: "Longest", color: .blue)
                Divider().frame(height: 44)
                streakColumn(value: "\(entries.count)", label: "Total Days", color: .primary)
            }
        }
        .appCard()
    }

    private func streakColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Compliance Card

    private var complianceCard: some View {
        let compliance = weeklyCompliance
        let compColor: Color = compliance.percentage >= 85 ? .green : compliance.percentage >= 50 ? .orange : .red

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Weekly Compliance", icon: "checkmark.circle.fill", color: .blue)

            HStack {
                Text("\(compliance.taken)/\(compliance.total) days this week")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(compliance.percentage))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(compColor)
                    .monospacedDigit()
            }

            GradientProgressBar(value: compliance.percentage / 100, color: compColor, height: 8)

            if compliance.percentage >= 85 {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
                    Text("Consistent — great work!")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .appCard()
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Last 28 Days", icon: "calendar", color: .blue)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(last28Days, id: \.date) { day in
                    VStack(spacing: 2) {
                        Text(day.date, format: .dateTime.day())
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        ZStack {
                            Circle()
                                .fill(day.taken ? Color.blue : Color(.systemGray5))
                                .frame(width: 26, height: 26)
                            if day.taken {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Chart Card

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "30-Day Intake", icon: "chart.bar.fill", color: .blue)

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
            }
        }
        .appCard()
    }

    // MARK: - Recent History Card

    private var recentHistoryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent History", icon: "list.bullet", color: .secondary)

            if entries.isEmpty {
                Text("No entries yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    let prefixed = Array(entries.prefix(14))
                    ForEach(Array(prefixed.enumerated()), id: \.element.id) { idx, entry in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle().fill(Color.blue.opacity(0.12)).frame(width: 32, height: 32)
                                Image(systemName: "pill.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.0f", entry.grams))g creatine")
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if idx < prefixed.count - 1 {
                            Divider().padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .appCard()
    }

    // MARK: - Undo Bar

    private var undoBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "pill.fill").foregroundStyle(.blue)
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
            .font(.subheadline.bold()).foregroundStyle(.blue)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func logCreatine() {
        let entry = CreatineEntry(grams: dose)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
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
    NavigationStack { CreatineTrackerView() }
        .modelContainer(for: [CreatineEntry.self, UserSettings.self], inMemory: true)
}
