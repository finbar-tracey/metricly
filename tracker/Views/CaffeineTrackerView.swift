import SwiftUI
import SwiftData
import Charts

struct CaffeineTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CaffeineEntry.date, order: .reverse) private var entries: [CaffeineEntry]
    @Query private var settingsArray: [UserSettings]

    @State private var selectedSource = "Coffee"
    @State private var customMg = ""
    @State private var entryToDelete: CaffeineEntry?
    @State private var editingEntry: CaffeineEntry?
    @State private var editMg: String = ""
    @State private var editSource: String = ""
    @State private var showTimePicker = false
    @State private var customDate = Date.now
    @State private var historyRange: HistoryRange = .week
    @State private var lastAddedEntry: CaffeineEntry?
    @State private var showUndo = false
    @State private var undoWorkItem: DispatchWorkItem?
    @State private var sleepData: [(date: Date, minutes: Double)] = []
    @FocusState private var isMgFocused: Bool

    private var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    private var halfLife: Double {
        settings.caffeineHalfLife
    }

    private var dailyLimit: Double {
        Double(settings.dailyCaffeineLimit)
    }

    enum HistoryRange: String, CaseIterable {
        case week = "7D"
        case month = "30D"
    }

    // MARK: - Computed

    private func totalRemainingMg(at now: Date) -> Double {
        entries.reduce(0) { $0 + $1.remainingCaffeine(at: now, halfLifeHours: halfLife) }
    }

    private func sleepReadiness(_ mg: Double) -> (label: String, color: Color, icon: String) {
        if mg < 25 { return ("Ready for Sleep", .green, "moon.zzz.fill") }
        if mg < 50 { return ("Winding Down", .yellow, "moon.fill") }
        if mg < 100 { return ("Elevated", .orange, "exclamationmark.triangle.fill") }
        return ("Too Stimulated", .red, "bolt.fill")
    }

    private var defaultMgForSource: Double {
        CaffeineEntry.presets.first { $0.name == selectedSource }?.mg ?? 0
    }

    private var effectiveMg: Double {
        if let custom = Double(customMg), custom > 0 { return custom }
        return defaultMgForSource
    }

    /// Today's total consumed mg (not remaining — total intake)
    private var todayTotalMg: Double {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return entries.filter { $0.date >= startOfDay }.reduce(0) { $0 + $1.milligrams }
    }

    /// Top 3 most frequently logged sources
    private var frequentSources: [(name: String, mg: Double, icon: String, count: Int)] {
        let last30 = entries.filter { $0.date > Calendar.current.date(byAdding: .day, value: -30, to: .now)! }
        var counts: [String: Int] = [:]
        for entry in last30 {
            counts[entry.source, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { (source, count) in
                if let preset = CaffeineEntry.presets.first(where: { $0.name == source }) {
                    return (name: preset.name, mg: preset.mg, icon: preset.icon, count: count)
                }
                // Custom source — find average mg
                let avg = last30.filter { $0.source == source }.map(\.milligrams).reduce(0, +) / Double(count)
                return (name: source, mg: avg, icon: "pill.fill", count: count)
            }
    }

    /// Daily totals for history chart
    private func dailyTotals(days: Int) -> [(date: Date, mg: Double)] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        return (0..<days).reversed().map { offset in
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            let total = entries.filter { $0.date >= day && $0.date < nextDay }.reduce(0) { $0 + $1.milligrams }
            return (date: day, mg: total)
        }
    }

    /// Time-of-day breakdown
    private var timeOfDayBreakdown: [(period: String, icon: String, color: Color, mg: Double, count: Int)] {
        let last30 = entries.filter { $0.date > Calendar.current.date(byAdding: .day, value: -30, to: .now)! }
        let cal = Calendar.current

        var morning: (mg: Double, count: Int) = (0, 0)   // 5-12
        var afternoon: (mg: Double, count: Int) = (0, 0)  // 12-17
        var evening: (mg: Double, count: Int) = (0, 0)    // 17-21
        var night: (mg: Double, count: Int) = (0, 0)      // 21-5

        for entry in last30 {
            let hour = cal.component(.hour, from: entry.date)
            switch hour {
            case 5..<12:
                morning.mg += entry.milligrams
                morning.count += 1
            case 12..<17:
                afternoon.mg += entry.milligrams
                afternoon.count += 1
            case 17..<21:
                evening.mg += entry.milligrams
                evening.count += 1
            default:
                night.mg += entry.milligrams
                night.count += 1
            }
        }

        return [
            ("Morning", "sunrise.fill", .orange, morning.mg, morning.count),
            ("Afternoon", "sun.max.fill", .yellow, afternoon.mg, afternoon.count),
            ("Evening", "sunset.fill", .indigo, evening.mg, evening.count),
            ("Night", "moon.stars.fill", .purple, night.mg, night.count)
        ]
    }

    /// Stats for the selected history range
    private func historyStats(days: Int) -> (avgPerDay: Double, total: Double, daysTracked: Int) {
        let data = dailyTotals(days: days)
        let daysWithData = data.filter { $0.mg > 0 }.count
        let total = data.reduce(0) { $0 + $1.mg }
        let avg = daysWithData > 0 ? total / Double(daysWithData) : 0
        return (avg, total, daysWithData)
    }

    /// Caffeine-free day streak (consecutive days ending today with 0mg logged)
    private var caffeineFreeStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var streak = 0
        for offset in 0..<90 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            let hadCaffeine = entries.contains { $0.date >= day && $0.date < nextDay }
            if hadCaffeine { break }
            streak += 1
        }
        return streak
    }

    /// Days since last caffeine-free day (if currently on caffeine)
    private var daysSinceFreeDayText: String? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        // If today is caffeine-free, don't show this
        let todayEnd = cal.date(byAdding: .day, value: 1, to: today)!
        let hadCaffeineToday = entries.contains { $0.date >= today && $0.date < todayEnd }
        guard hadCaffeineToday else { return nil }
        for offset in 1..<90 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            let hadCaffeine = entries.contains { $0.date >= day && $0.date < nextDay }
            if !hadCaffeine {
                return offset == 1 ? "Yesterday" : "\(offset) days ago"
            }
        }
        return nil
    }

    /// Peak system caffeine time — most recent entry + ~45min absorption
    private var peakCaffeineInfo: (peakTime: Date, peakMg: Double)? {
        let now = Date.now
        let hl = halfLife
        // Only consider entries from today that are still active
        let recentActive = entries.filter { $0.remainingCaffeine(at: now, halfLifeHours: hl) > 1 }
        guard let latest = recentActive.first else { return nil }

        // Caffeine peaks ~45 min after ingestion
        let absorptionMinutes: TimeInterval = 45 * 60
        let peakTime = latest.date.addingTimeInterval(absorptionMinutes)

        // If the peak is already past, don't show it
        guard peakTime > now else { return nil }

        // Estimate total system caffeine at peak time
        let peakMg = recentActive.reduce(0.0) { $0 + $1.remainingCaffeine(at: peakTime, halfLifeHours: hl) }
        return (peakTime, peakMg)
    }

    private struct DecayPoint: Identifiable {
        let id = UUID()
        let date: Date
        let mg: Double
    }

    private func decayCurveData(from now: Date) -> [DecayPoint] {
        let hl = halfLife
        let recentEntries = entries.filter { $0.remainingCaffeine(at: now, halfLifeHours: hl) > 0.1 }
        return (0...48).map { i in
            let time = now.addingTimeInterval(Double(i) * 900)
            let total = recentEntries.reduce(0.0) { $0 + $1.remainingCaffeine(at: time, halfLifeHours: hl) }
            return DecayPoint(date: time, mg: total)
        }
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let remaining = totalRemainingMg(at: now)
            let readiness = sleepReadiness(remaining)
            List {
                Section {
                    currentStatusView(remaining: remaining, readiness: readiness)
                }

                // Quick Log (favorites)
                if !frequentSources.isEmpty {
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(frequentSources, id: \.name) { fav in
                                    Button {
                                        quickLog(source: fav.name, mg: fav.mg)
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: fav.icon)
                                                .font(.caption)
                                            Text(fav.name)
                                                .font(.caption.bold())
                                            Text("\(Int(fav.mg))mg")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.brown.opacity(0.12), in: Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    } header: {
                        HStack {
                            Image(systemName: "bolt.heart.fill")
                            Text("Quick Log")
                        }
                    }
                }

                // Daily budget
                Section {
                    dailyBudgetView
                }

                // Caffeine-free streak
                if caffeineFreeStreak > 0 || daysSinceFreeDayText != nil {
                    Section {
                        caffeineStreakView
                    }
                }

                if remaining > 0.5 {
                    Section("Caffeine Decay") {
                        decayChartView(from: now)
                            .frame(height: 200)
                            .padding(.vertical, 8)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }
                }

                Section("Log Caffeine") {
                    sourcePickerView
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    mgInputRow
                    timestampRow
                    logButton
                }

                // Weekly/monthly history
                Section {
                    Picker("Range", selection: $historyRange) {
                        ForEach(HistoryRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))

                    historyStatsRow

                    historyChartView
                        .frame(height: 180)
                        .padding(.vertical, 4)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Text("Daily History")
                }

                // Time-of-day pattern
                if entries.count >= 3 {
                    Section {
                        timeOfDayView
                    } header: {
                        Text("When You Drink (30 Days)")
                    }
                }

                // Sleep correlation
                if !sleepData.isEmpty && entries.count >= 5 {
                    Section {
                        sleepCorrelationView
                    } header: {
                        HStack {
                            Image(systemName: "moon.zzz.fill")
                            Text("Sleep Impact")
                        }
                    }
                }

                Section("Recent Intake") {
                    if entries.isEmpty {
                        Text("No caffeine logged yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries.prefix(20)) { entry in
                            intakeRow(entry)
                        }
                        .onDelete { offsets in
                            if let index = offsets.first {
                                entryToDelete = Array(entries.prefix(20))[index]
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Caffeine Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMgFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showUndo {
                undoBar
            }
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete {
                    modelContext.delete(entry)
                    entryToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("Remove this caffeine entry?")
        }
        .alert("Edit Entry", isPresented: Binding(
            get: { editingEntry != nil },
            set: { if !$0 { editingEntry = nil } }
        )) {
            TextField("mg", text: $editMg)
                .keyboardType(.decimalPad)
            Button("Save") {
                if let entry = editingEntry, let mg = Double(editMg), mg > 0 {
                    entry.milligrams = mg
                    entry.source = editSource
                }
                editingEntry = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = editingEntry {
                    modelContext.delete(entry)
                }
                editingEntry = nil
            }
            Button("Cancel", role: .cancel) { editingEntry = nil }
        } message: {
            if let entry = editingEntry {
                Text("Edit \(entry.source) — \(Int(entry.milligrams)) mg")
            }
        }
        .task {
            await loadSleepData()
        }
    }

    // MARK: - Current Status

    private func currentStatusView(remaining: Double, readiness: (label: String, color: Color, icon: String)) -> some View {
        let now = Date.now
        return VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.quaternary, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: min(1.0, remaining / dailyLimit))
                    .stroke(readiness.color.gradient,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.8), value: remaining)
                VStack(spacing: 2) {
                    Text("\(Int(remaining))")
                        .font(.title.bold().monospacedDigit())
                    Text("mg remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 110, height: 110)

            HStack(spacing: 6) {
                Image(systemName: readiness.icon)
                    .foregroundStyle(readiness.color)
                Text(readiness.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(readiness.color)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(readiness.color.opacity(0.1), in: Capsule())

            if let clearTime = caffeineClearTime(from: now), remaining >= 25 {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Text("Sleep-ready by ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text(clearTime, format: .dateTime.hour().minute())
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }

            if let peak = peakCaffeineInfo {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.to.line")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text("Peak ~\(Int(peak.peakMg))mg at ")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    + Text(peak.peakTime, format: .dateTime.hour().minute())
                        .font(.caption.bold())
                        .foregroundStyle(.orange)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Daily Budget

    private var dailyBudgetView: some View {
        let consumed = todayTotalMg
        let limit = dailyLimit
        let progress = min(1.0, consumed / limit)
        let overLimit = consumed > limit
        let color: Color = overLimit ? .red : (progress > 0.75 ? .orange : .brown)

        return VStack(spacing: 10) {
            HStack {
                Label("Today's Intake", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(consumed)) / \(Int(limit)) mg")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(color)
            }
            ProgressView(value: progress)
                .tint(color)
            if overLimit {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Over daily limit by \(Int(consumed - limit)) mg")
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Caffeine-Free Streak

    private var caffeineStreakView: some View {
        HStack(spacing: 12) {
            let streak = caffeineFreeStreak
            if streak > 0 {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(streak) caffeine-free day\(streak == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                    Text("Keep it going!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if let lastFree = daysSinceFreeDayText {
                ZStack {
                    Circle()
                        .fill(Color.brown.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "cup.and.saucer.fill")
                        .foregroundStyle(.brown)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last caffeine-free day")
                        .font(.subheadline.weight(.semibold))
                    Text(lastFree)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - History Stats

    private var historyStatsRow: some View {
        let days = historyRange == .week ? 7 : 30
        let stats = historyStats(days: days)
        return HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("\(Int(stats.avgPerDay))")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("avg mg/day")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 28)

            VStack(spacing: 2) {
                Text("\(Int(stats.total))")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("total mg")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)

            Divider().frame(height: 28)

            VStack(spacing: 2) {
                Text("\(stats.daysTracked)")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .monospacedDigit()
                Text("days tracked")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Caffeine Clear Time

    private func caffeineClearTime(from now: Date) -> Date? {
        let remaining = totalRemainingMg(at: now)
        guard remaining >= 25 else { return nil }
        var lo: TimeInterval = 0
        var hi: TimeInterval = 24 * 3600
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            if totalRemainingMg(at: now.addingTimeInterval(mid)) > 25 {
                lo = mid
            } else {
                hi = mid
            }
        }
        return now.addingTimeInterval(hi)
    }

    // MARK: - Decay Chart

    private func decayChartView(from now: Date) -> some View {
        let data = decayCurveData(from: now)
        let clearTime = caffeineClearTime(from: now)
        return Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("Time", point.date),
                    y: .value("Caffeine", point.mg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.brown)

                AreaMark(
                    x: .value("Time", point.date),
                    y: .value("Caffeine", point.mg)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(Color.brown.opacity(0.15).gradient)
            }

            RuleMark(y: .value("Sleep Ready", 25))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.green.opacity(0.6))
                .annotation(position: .leading, alignment: .leading) {
                    Text("Sleep")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }

            if let clearTime {
                RuleMark(x: .value("Clear", clearTime))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.green.opacity(0.5))
                    .annotation(position: .top, alignment: .center) {
                        Text(clearTime, format: .dateTime.hour().minute())
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                    }
            }
        }
        .chartYAxisLabel("mg")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: .dateTime.hour().minute())
            }
        }
    }

    // MARK: - History Chart

    private var historyChartView: some View {
        let days = historyRange == .week ? 7 : 30
        let data = dailyTotals(days: days)
        let limit = dailyLimit
        return Chart {
            ForEach(data, id: \.date) { point in
                BarMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("mg", point.mg)
                )
                .foregroundStyle(point.mg > limit ? Color.red.gradient : Color.brown.gradient)
                .cornerRadius(4)
            }

            RuleMark(y: .value("Limit", limit))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                .foregroundStyle(.red.opacity(0.5))
                .annotation(position: .trailing, alignment: .trailing) {
                    Text("\(Int(limit))")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
        }
        .chartYAxisLabel("mg")
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: days <= 7 ? 1 : 5)) { _ in
                AxisGridLine()
                AxisValueLabel(format: days <= 7 ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day())
            }
        }
    }

    // MARK: - Time of Day

    private var timeOfDayView: some View {
        let breakdown = timeOfDayBreakdown
        let maxMg = breakdown.map(\.mg).max() ?? 1

        return VStack(spacing: 8) {
            ForEach(breakdown, id: \.period) { item in
                HStack(spacing: 10) {
                    Image(systemName: item.icon)
                        .foregroundStyle(item.color)
                        .frame(width: 20)
                    Text(item.period)
                        .font(.caption)
                        .frame(width: 65, alignment: .leading)
                    GeometryReader { geo in
                        let width = max(0, geo.size.width * (maxMg > 0 ? item.mg / maxMg : 0))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(item.color.gradient)
                            .frame(width: width)
                    }
                    .frame(height: 16)
                    Text("\(Int(item.mg))mg")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Sleep Correlation

    private var sleepCorrelationView: some View {
        let cal = Calendar.current
        let last30 = entries.filter { $0.date > cal.date(byAdding: .day, value: -30, to: .now)! }

        // Split days into "afternoon caffeine" vs "morning only"
        var afternoonDays: [Double] = []
        var morningOnlyDays: [Double] = []

        for sleepDay in sleepData {
            guard sleepDay.minutes > 0 else { continue }
            let dayStart = cal.startOfDay(for: sleepDay.date)
            let noon = cal.date(bySettingHour: 14, minute: 0, second: 0, of: dayStart)!
            let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!

            let hadAfternoonCaffeine = last30.contains { $0.date >= noon && $0.date < dayEnd }
            if hadAfternoonCaffeine {
                afternoonDays.append(sleepDay.minutes)
            } else {
                morningOnlyDays.append(sleepDay.minutes)
            }
        }

        let avgAfternoon = afternoonDays.isEmpty ? 0 : afternoonDays.reduce(0, +) / Double(afternoonDays.count)
        let avgMorning = morningOnlyDays.isEmpty ? 0 : morningOnlyDays.reduce(0, +) / Double(morningOnlyDays.count)

        let hasData = !afternoonDays.isEmpty && !morningOnlyDays.isEmpty
        let diff = avgMorning - avgAfternoon

        return VStack(alignment: .leading, spacing: 12) {
            if hasData {
                HStack(spacing: 16) {
                    sleepStatPill(
                        label: "Morning Only",
                        hours: avgMorning / 60,
                        color: .green,
                        icon: "sunrise.fill"
                    )
                    sleepStatPill(
                        label: "After 2 PM",
                        hours: avgAfternoon / 60,
                        color: .orange,
                        icon: "sun.max.fill"
                    )
                }

                if diff > 15 {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.orange)
                        Text("Caffeine after 2 PM is linked to **\(Int(diff))min less** sleep on average.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("No significant sleep impact from afternoon caffeine detected.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("Need more data to analyze sleep impact. Keep logging!")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func sleepStatPill(label: String, hours: Double, color: Color, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(String(format: "%.1fh", hours))
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Source Picker

    private var sourcePickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CaffeineEntry.presets, id: \.name) { preset in
                    Button {
                        selectedSource = preset.name
                        if preset.name != "Other" { customMg = "" }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: preset.icon)
                                .font(.system(size: 18))
                            Text(preset.name)
                                .font(.caption2)
                                .lineLimit(1)
                            if preset.mg > 0 {
                                Text("\(Int(preset.mg))mg")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 70, height: 65)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedSource == preset.name
                                      ? Color.brown.opacity(0.15)
                                      : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedSource == preset.name
                                        ? Color.brown : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - mg Input

    private var mgInputRow: some View {
        HStack {
            Text("Amount")
                .foregroundStyle(.secondary)
            Spacer()
            TextField(
                selectedSource == "Other" ? "mg" : "\(Int(defaultMgForSource)) mg",
                text: $customMg
            )
            .keyboardType(.decimalPad)
            .focused($isMgFocused)
            .multilineTextAlignment(.trailing)
            .frame(width: 100)
            Text("mg")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Timestamp Row

    private var timestampRow: some View {
        HStack {
            Text("Time")
                .foregroundStyle(.secondary)
            Spacer()
            if showTimePicker {
                DatePicker("", selection: $customDate, in: ...Date.now, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .fixedSize()
                Button("Now") {
                    customDate = .now
                    showTimePicker = false
                }
                .font(.caption.bold())
                .foregroundStyle(.brown)
            } else {
                Button {
                    customDate = .now
                    showTimePicker = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Now")
                            .font(.subheadline)
                        Image(systemName: "clock")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Log Button

    private var logButton: some View {
        Button {
            logCaffeine()
        } label: {
            HStack {
                Spacer()
                Image(systemName: "plus.circle.fill")
                Text("Log \(Int(effectiveMg)) mg \(selectedSource)")
                    .font(.subheadline.bold())
                Spacer()
            }
        }
        .disabled(effectiveMg <= 0)
    }

    // MARK: - Undo Bar

    private var undoBar: some View {
        HStack {
            Image(systemName: "cup.and.saucer.fill")
                .foregroundStyle(.brown)
            Text("Caffeine logged")
                .font(.subheadline)
            Spacer()
            Button {
                undoLastEntry()
            } label: {
                Text("Undo")
                    .font(.subheadline.bold())
                    .foregroundStyle(.brown)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Intake Row

    private func intakeRow(_ entry: CaffeineEntry) -> some View {
        Button {
            editMg = "\(Int(entry.milligrams))"
            editSource = entry.source
            editingEntry = entry
        } label: {
            HStack {
                let preset = CaffeineEntry.presets.first { $0.name == entry.source }
                Image(systemName: preset?.icon ?? "pill.fill")
                    .foregroundStyle(.brown)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.source)
                        .font(.subheadline.weight(.semibold))
                    Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(Int(entry.milligrams)) mg")
                        .font(.subheadline.bold().monospacedDigit())
                    let remaining = entry.remainingCaffeine(halfLifeHours: halfLife)
                    if remaining > 0.5 {
                        Text("\(Int(remaining)) mg left")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Fully metabolized")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func logCaffeine() {
        let date = showTimePicker ? customDate : .now
        let entry = CaffeineEntry(date: date, milligrams: effectiveMg, source: selectedSource)
        modelContext.insert(entry)
        customMg = ""
        showTimePicker = false
        customDate = .now
        isMgFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUndoSnackbar(for: entry)
    }

    private func quickLog(source: String, mg: Double) {
        let entry = CaffeineEntry(milligrams: mg, source: source)
        modelContext.insert(entry)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showUndoSnackbar(for: entry)
    }

    private func showUndoSnackbar(for entry: CaffeineEntry) {
        lastAddedEntry = entry
        undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            showUndo = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) {
                showUndo = false
            }
            lastAddedEntry = nil
        }
        undoWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    private func undoLastEntry() {
        guard let entry = lastAddedEntry else { return }
        modelContext.delete(entry)
        lastAddedEntry = nil
        undoWorkItem?.cancel()
        withAnimation(.easeInOut(duration: 0.25)) {
            showUndo = false
        }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func loadSleepData() async {
        guard settings.healthKitEnabled else { return }
        do {
            sleepData = try await HealthKitManager.shared.fetchDailySleep(days: 30)
        } catch {
            sleepData = []
        }
    }
}

#Preview {
    NavigationStack {
        CaffeineTrackerView()
    }
    .modelContainer(for: [CaffeineEntry.self, UserSettings.self], inMemory: true)
}
