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

    private var settings: UserSettings { settingsArray.first ?? UserSettings() }
    private var halfLife: Double { settings.caffeineHalfLife }
    private var dailyLimit: Double { Double(settings.dailyCaffeineLimit) }

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

    private var todayTotalMg: Double {
        let startOfDay = Calendar.current.startOfDay(for: .now)
        return entries.filter { $0.date >= startOfDay }.reduce(0) { $0 + $1.milligrams }
    }

    private var frequentSources: [(name: String, mg: Double, icon: String, count: Int)] {
        let last30 = entries.filter { $0.date > Calendar.current.date(byAdding: .day, value: -30, to: .now)! }
        var counts: [String: Int] = [:]
        for entry in last30 { counts[entry.source, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }
            .prefix(3)
            .compactMap { (source, count) in
                if let preset = CaffeineEntry.presets.first(where: { $0.name == source }) {
                    return (name: preset.name, mg: preset.mg, icon: preset.icon, count: count)
                }
                let avg = last30.filter { $0.source == source }.map(\.milligrams).reduce(0, +) / Double(count)
                return (name: source, mg: avg, icon: "pill.fill", count: count)
            }
    }

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

    private var timeOfDayBreakdown: [(period: String, icon: String, color: Color, mg: Double, count: Int)] {
        let last30 = entries.filter { $0.date > Calendar.current.date(byAdding: .day, value: -30, to: .now)! }
        let cal = Calendar.current
        var morning: (mg: Double, count: Int) = (0, 0)
        var afternoon: (mg: Double, count: Int) = (0, 0)
        var evening: (mg: Double, count: Int) = (0, 0)
        var night: (mg: Double, count: Int) = (0, 0)

        for entry in last30 {
            let hour = cal.component(.hour, from: entry.date)
            switch hour {
            case 5..<12: morning.mg += entry.milligrams; morning.count += 1
            case 12..<17: afternoon.mg += entry.milligrams; afternoon.count += 1
            case 17..<21: evening.mg += entry.milligrams; evening.count += 1
            default: night.mg += entry.milligrams; night.count += 1
            }
        }
        return [
            ("Morning", "sunrise.fill", .orange, morning.mg, morning.count),
            ("Afternoon", "sun.max.fill", .yellow, afternoon.mg, afternoon.count),
            ("Evening", "sunset.fill", .indigo, evening.mg, evening.count),
            ("Night", "moon.stars.fill", .purple, night.mg, night.count)
        ]
    }

    private func historyStats(days: Int) -> (avgPerDay: Double, total: Double, daysTracked: Int) {
        let data = dailyTotals(days: days)
        let daysWithData = data.filter { $0.mg > 0 }.count
        let total = data.reduce(0) { $0 + $1.mg }
        let avg = daysWithData > 0 ? total / Double(daysWithData) : 0
        return (avg, total, daysWithData)
    }

    private var caffeineFreeStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        var streak = 0
        for offset in 0..<90 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            if entries.contains(where: { $0.date >= day && $0.date < nextDay }) { break }
            streak += 1
        }
        return streak
    }

    private var daysSinceFreeDayText: String? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        let todayEnd = cal.date(byAdding: .day, value: 1, to: today)!
        guard entries.contains(where: { $0.date >= today && $0.date < todayEnd }) else { return nil }
        for offset in 1..<90 {
            let day = cal.date(byAdding: .day, value: -offset, to: today)!
            let nextDay = cal.date(byAdding: .day, value: 1, to: day)!
            if !entries.contains(where: { $0.date >= day && $0.date < nextDay }) {
                return offset == 1 ? "Yesterday" : "\(offset) days ago"
            }
        }
        return nil
    }

    private var peakCaffeineInfo: (peakTime: Date, peakMg: Double)? {
        let now = Date.now
        let hl = halfLife
        let recentActive = entries.filter { $0.remainingCaffeine(at: now, halfLifeHours: hl) > 1 }
        guard let latest = recentActive.first else { return nil }
        let peakTime = latest.date.addingTimeInterval(45 * 60)
        guard peakTime > now else { return nil }
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

    private func caffeineClearTime(from now: Date) -> Date? {
        let remaining = totalRemainingMg(at: now)
        guard remaining >= 25 else { return nil }
        var lo: TimeInterval = 0
        var hi: TimeInterval = 24 * 3600
        for _ in 0..<30 {
            let mid = (lo + hi) / 2
            if totalRemainingMg(at: now.addingTimeInterval(mid)) > 25 { lo = mid } else { hi = mid }
        }
        return now.addingTimeInterval(hi)
    }

    // MARK: - Body

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            let now = context.date
            let remaining = totalRemainingMg(at: now)
            let readiness = sleepReadiness(remaining)

            ScrollView {
                LazyVStack(spacing: AppTheme.sectionSpacing) {
                    heroCard(remaining: remaining, readiness: readiness, now: now)

                    if !frequentSources.isEmpty {
                        quickLogCard
                    }

                    dailyBudgetCard(remaining: remaining)

                    if remaining > 0.5 {
                        decayCard(from: now)
                    }

                    logCaffeineCard

                    historyCard

                    if entries.count >= 3 {
                        timeOfDayCard
                    }

                    if caffeineFreeStreak > 0 || daysSinceFreeDayText != nil {
                        streakCard
                    }

                    if !entries.isEmpty {
                        recentIntakeCard
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Caffeine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isMgFocused = false }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if showUndo { undoBar }
        }
        .alert("Delete Entry?", isPresented: Binding(
            get: { entryToDelete != nil },
            set: { if !$0 { entryToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = entryToDelete { modelContext.delete(entry); entryToDelete = nil }
            }
            Button("Cancel", role: .cancel) { entryToDelete = nil }
        } message: {
            Text("Remove this caffeine entry?")
        }
        .alert("Edit Entry", isPresented: Binding(
            get: { editingEntry != nil },
            set: { if !$0 { editingEntry = nil } }
        )) {
            TextField("mg", text: $editMg).keyboardType(.decimalPad)
            Button("Save") {
                if let entry = editingEntry, let mg = Double(editMg), mg > 0 {
                    entry.milligrams = mg; entry.source = editSource
                }
                editingEntry = nil
            }
            Button("Delete", role: .destructive) {
                if let entry = editingEntry { modelContext.delete(entry) }
                editingEntry = nil
            }
            Button("Cancel", role: .cancel) { editingEntry = nil }
        } message: {
            if let entry = editingEntry { Text("Edit \(entry.source) — \(Int(entry.milligrams)) mg") }
        }
        .task { await loadSleepData() }
    }

    // MARK: - Hero Card

    private func heroCard(remaining: Double, readiness: (label: String, color: Color, icon: String), now: Date) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.brown, Color.orange.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle().stroke(.white.opacity(0.20), lineWidth: 8)
                        Circle()
                            .trim(from: 0, to: min(1.0, remaining / dailyLimit))
                            .stroke(.white, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeInOut(duration: 0.8), value: remaining)
                        VStack(spacing: 1) {
                            Text("\(Int(remaining))")
                                .font(.system(size: 26, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                            Text("mg").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.80))
                        }
                    }
                    .frame(width: 80, height: 80)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("System Caffeine")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))

                        HStack(spacing: 5) {
                            Image(systemName: readiness.icon).font(.caption)
                            Text(readiness.label).font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.white.opacity(0.20), in: Capsule())

                        if let clearTime = caffeineClearTime(from: now), remaining >= 25 {
                            HStack(spacing: 4) {
                                Image(systemName: "moon.zzz.fill").font(.caption2).foregroundStyle(.white.opacity(0.8))
                                (Text("Clear by ") + Text(clearTime, format: .dateTime.hour().minute()).bold())
                                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                            }
                        }

                        if let peak = peakCaffeineInfo {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.up.to.line").font(.caption2).foregroundStyle(.white.opacity(0.8))
                                (Text("Peak ~\(Int(peak.peakMg))mg at ")
                                 + Text(peak.peakTime, format: .dateTime.hour().minute()).bold())
                                    .font(.caption).foregroundStyle(.white.opacity(0.85))
                            }
                        }
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    heroStatCol("Today", value: "\(Int(todayTotalMg))mg")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Limit", value: "\(Int(dailyLimit))mg")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    heroStatCol("Remaining", value: "\(Int(remaining))mg")
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

    // MARK: - Quick Log Card

    private var quickLogCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Log", icon: "bolt.heart.fill", color: .brown)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(frequentSources, id: \.name) { fav in
                        Button { quickLog(source: fav.name, mg: fav.mg) } label: {
                            HStack(spacing: 6) {
                                Image(systemName: fav.icon).font(.caption)
                                Text(fav.name).font(.caption.bold())
                                Text("\(Int(fav.mg))mg").font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(Color.brown.opacity(0.12), in: Capsule())
                            .foregroundStyle(Color.brown)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Daily Budget Card

    private func dailyBudgetCard(remaining: Double) -> some View {
        let consumed = todayTotalMg
        let limit = dailyLimit
        let progress = min(1.0, consumed / limit)
        let overLimit = consumed > limit
        let color: Color = overLimit ? .red : (progress > 0.75 ? .orange : .brown)

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Daily Budget", icon: "chart.bar.fill", color: color)
                Spacer()
                Text("\(Int(consumed)) / \(Int(limit)) mg")
                    .font(.caption.bold().monospacedDigit()).foregroundStyle(color)
            }

            GradientProgressBar(value: progress, color: color, height: 8)

            if overLimit {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption)
                    Text("Over daily limit by \(Int(consumed - limit)) mg")
                        .font(.caption).foregroundStyle(.red)
                }
            }
        }
        .appCard()
    }

    // MARK: - Decay Card

    private func decayCard(from now: Date) -> some View {
        let data = decayCurveData(from: now)
        let clearTime = caffeineClearTime(from: now)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Caffeine Decay", icon: "waveform.path.ecg", color: .brown)
            Chart {
                ForEach(data) { point in
                    LineMark(x: .value("Time", point.date), y: .value("Caffeine", point.mg))
                        .interpolationMethod(.catmullRom).foregroundStyle(Color.brown)
                    AreaMark(x: .value("Time", point.date), y: .value("Caffeine", point.mg))
                        .interpolationMethod(.catmullRom).foregroundStyle(Color.brown.opacity(0.15).gradient)
                }
                RuleMark(y: .value("Sleep Ready", 25))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.green.opacity(0.6))
                    .annotation(position: .leading, alignment: .leading) {
                        Text("Sleep").font(.caption2).foregroundStyle(.green)
                    }
                if let clearTime {
                    RuleMark(x: .value("Clear", clearTime))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        .foregroundStyle(.green.opacity(0.5))
                        .annotation(position: .top, alignment: .center) {
                            Text(clearTime, format: .dateTime.hour().minute())
                                .font(.caption2.bold()).foregroundStyle(.green)
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
            .frame(height: 200).padding(.vertical, 4)
        }
        .appCard()
    }

    // MARK: - Log Caffeine Card

    private var logCaffeineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Caffeine", icon: "plus.circle.fill", color: .brown)

            sourcePickerView.padding(.bottom, 4)

            VStack(spacing: 0) {
                HStack {
                    Text("Amount").foregroundStyle(.secondary).font(.subheadline)
                    Spacer()
                    TextField(
                        selectedSource == "Other" ? "mg" : "\(Int(defaultMgForSource)) mg",
                        text: $customMg
                    )
                    .keyboardType(.decimalPad).focused($isMgFocused)
                    .multilineTextAlignment(.trailing).frame(width: 80).font(.subheadline)
                    Text("mg").foregroundStyle(.secondary).font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 16)

                HStack {
                    Text("Time").foregroundStyle(.secondary).font(.subheadline)
                    Spacer()
                    if showTimePicker {
                        DatePicker("", selection: $customDate, in: ...Date.now,
                                   displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden().fixedSize()
                        Button("Now") { customDate = .now; showTimePicker = false }
                            .font(.caption.bold()).foregroundStyle(.brown)
                    } else {
                        Button {
                            customDate = .now; showTimePicker = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("Now").font(.subheadline)
                                Image(systemName: "clock").font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 16)

                Button { logCaffeine() } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Log \(Int(effectiveMg)) mg \(selectedSource)").font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 14)
                    .background(effectiveMg <= 0 ? Color(.systemFill) : Color.brown.opacity(0.9))
                    .foregroundStyle(effectiveMg <= 0 ? Color.secondary : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .disabled(effectiveMg <= 0)
                .buttonStyle(.plain)
                .padding(.horizontal, 16).padding(.vertical, 12)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private var sourcePickerView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(CaffeineEntry.presets, id: \.name) { preset in
                    Button {
                        selectedSource = preset.name
                        if preset.name != "Other" { customMg = "" }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: preset.icon).font(.system(size: 18))
                            Text(preset.name).font(.caption2).lineLimit(1)
                            if preset.mg > 0 {
                                Text("\(Int(preset.mg))mg").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 70, height: 65)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(selectedSource == preset.name ? Color.brown.opacity(0.15) : Color(.systemGray6))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selectedSource == preset.name ? Color.brown : .clear, lineWidth: 1.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - History Card

    private var historyCard: some View {
        let days = historyRange == .week ? 7 : 30
        let stats = historyStats(days: days)
        let data = dailyTotals(days: days)
        let limit = dailyLimit

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Daily History", icon: "chart.bar.fill", color: .brown)

            HStack(spacing: 8) {
                ForEach(HistoryRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { historyRange = range }
                    } label: {
                        Text(range.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(historyRange == range ? Color.brown : Color(.secondarySystemFill),
                                        in: Capsule())
                            .foregroundStyle(historyRange == range ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }

            HStack(spacing: 0) {
                historyStatCol("Avg/Day", value: "\(Int(stats.avgPerDay))mg")
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 28)
                historyStatCol("Total", value: "\(Int(stats.total))mg")
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 28)
                historyStatCol("Days", value: "\(stats.daysTracked)")
            }
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Chart {
                ForEach(data, id: \.date) { point in
                    BarMark(x: .value("Date", point.date, unit: .day), y: .value("mg", point.mg))
                        .foregroundStyle(point.mg > limit ? Color.red.gradient : Color.brown.gradient)
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Limit", limit))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.red.opacity(0.5))
                    .annotation(position: .trailing, alignment: .trailing) {
                        Text("\(Int(limit))").font(.caption2).foregroundStyle(.red)
                    }
            }
            .chartYAxisLabel("mg")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: days <= 7 ? 1 : 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: days <= 7 ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180).padding(.vertical, 4)
        }
        .appCard()
    }

    private func historyStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Time of Day Card

    private var timeOfDayCard: some View {
        let breakdown = timeOfDayBreakdown
        let maxMg = breakdown.map(\.mg).max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "When You Drink (30 Days)", icon: "clock.fill", color: .brown)

            VStack(spacing: 10) {
                ForEach(breakdown, id: \.period) { item in
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6).fill(item.color.opacity(0.12)).frame(width: 28, height: 28)
                            Image(systemName: item.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(item.color)
                        }
                        Text(item.period).font(.caption).frame(width: 65, alignment: .leading)
                        GeometryReader { geo in
                            let width = max(0, geo.size.width * (maxMg > 0 ? item.mg / maxMg : 0))
                            RoundedRectangle(cornerRadius: 4).fill(item.color.gradient).frame(width: width)
                        }
                        .frame(height: 16)
                        Text("\(Int(item.mg))mg")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Streak Card

    private var streakCard: some View {
        let streak = caffeineFreeStreak
        return HStack(spacing: 16) {
            if streak > 0 {
                ZStack {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: "leaf.fill").font(.system(size: 20)).foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(streak) caffeine-free day\(streak == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                    Text("Keep it going!").font(.caption).foregroundStyle(.secondary)
                }
            } else if let lastFree = daysSinceFreeDayText {
                ZStack {
                    Circle().fill(Color.brown.opacity(0.12)).frame(width: 48, height: 48)
                    Image(systemName: "cup.and.saucer.fill").font(.system(size: 20)).foregroundStyle(.brown)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Last caffeine-free day").font(.subheadline.weight(.semibold))
                    Text(lastFree).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .appCard()
    }

    // MARK: - Recent Intake Card

    private var recentIntakeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Intake", icon: "clock.fill", color: .secondary)

            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(20).enumerated()), id: \.element.id) { idx, entry in
                    Button {
                        editMg = "\(Int(entry.milligrams))"; editSource = entry.source; editingEntry = entry
                    } label: {
                        intakeRowContent(entry)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { editMg = "\(Int(entry.milligrams))"; editSource = entry.source; editingEntry = entry } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { entryToDelete = entry } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if idx < min(entries.count, 20) - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func intakeRowContent(_ entry: CaffeineEntry) -> some View {
        let preset = CaffeineEntry.presets.first { $0.name == entry.source }
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.brown.opacity(0.12)).frame(width: 38, height: 38)
                Image(systemName: preset?.icon ?? "pill.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.brown)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.milligrams)) mg").font(.subheadline.bold().monospacedDigit()).foregroundStyle(.primary)
                let remaining = entry.remainingCaffeine(halfLifeHours: halfLife)
                if remaining > 0.5 {
                    Text("\(Int(remaining)) mg left").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Metabolized").font(.caption).foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: - Undo Bar

    private var undoBar: some View {
        HStack {
            Image(systemName: "cup.and.saucer.fill").foregroundStyle(.brown)
            Text("Caffeine logged").font(.subheadline)
            Spacer()
            Button { undoLastEntry() } label: {
                Text("Undo").font(.subheadline.bold()).foregroundStyle(.brown)
            }
        }
        .padding(.horizontal).padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Actions

    private func logCaffeine() {
        let date = showTimePicker ? customDate : .now
        let entry = CaffeineEntry(date: date, milligrams: effectiveMg, source: selectedSource)
        modelContext.insert(entry)
        customMg = ""; showTimePicker = false; customDate = .now; isMgFocused = false
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
        withAnimation(.easeInOut(duration: 0.25)) { showUndo = true }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.25)) { showUndo = false }
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
        withAnimation(.easeInOut(duration: 0.25)) { showUndo = false }
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
    NavigationStack { CaffeineTrackerView() }
        .modelContainer(for: [CaffeineEntry.self, UserSettings.self], inMemory: true)
}
