import SwiftUI
import SwiftData
import Charts

enum CreatineTrackerSections {

    static func heroCard(
        todayComplete: Bool,
        isLoadingPhase: Bool,
        hasTakenToday: Bool,
        dosesRemainingToday: Int,
        todayTotalGrams: Double,
        dailyTargetGrams: Double,
        dose: Double,
        todayEntryCount: Int,
        loadingDosesPerDay: Int,
        onLog: @escaping () -> Void
    ) -> some View {
        HeroCard(palette: todayComplete ? AppTheme.Gradients.recovery : AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .center, spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 76, height: 76)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        if todayComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(.white)
                        } else if isLoadingPhase {
                            VStack(spacing: 1) {
                                Text("\(todayEntryCount)/\(loadingDosesPerDay)")
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
                    Button(action: onLog) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill").font(.subheadline.bold())
                            Text("Log \(String(format: "%.0f", dose))g Creatine").font(.subheadline.bold())
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white, in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
            .padding(20)
        }
    }

    static func loadingPhaseCard(
        dose: Double,
        loadingDosesPerDay: Int,
        todayEntryCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                gradientDisc("bolt.fill", color: .yellow, size: 36, glyph: 14)
                Text("Loading Phase Active").font(.subheadline.weight(.semibold))
                Spacer()
            }
            Text("Take \(String(format: "%.0f", dose))g × \(loadingDosesPerDay) times/day (20g total) to saturate your muscles quickly. Typically lasts 5–7 days.")
                .font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                ForEach(0..<loadingDosesPerDay, id: \.self) { index in
                    ZStack {
                        Circle()
                            .fill(index < todayEntryCount ? Color.blue : Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        if index < todayEntryCount {
                            Image(systemName: "checkmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                Spacer()
                Text("\(todayEntryCount)/\(loadingDosesPerDay)")
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    static func streakCard(currentStreak: Int, longestStreak: Int, totalDays: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Streak", icon: "flame.fill", color: .orange)
            HStack(spacing: 0) {
                streakColumn(value: "\(currentStreak)", label: "Current", color: currentStreak >= 7 ? .blue : .primary)
                Divider().frame(height: 44)
                streakColumn(value: "\(longestStreak)", label: "Longest", color: .blue)
                Divider().frame(height: 44)
                streakColumn(value: "\(totalDays)", label: "Total Days", color: .primary)
            }
        }
        .appCard()
    }

    private static func streakColumn(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    static func complianceCard(_ compliance: CreatineEngine.WeeklyCompliance) -> some View {
        let compColor: Color = compliance.percentage >= 85 ? .green : compliance.percentage >= 50 ? .orange : .red
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Weekly Compliance", icon: "checkmark.circle.fill", color: .blue)
            HStack {
                Text("\(compliance.taken)/\(compliance.total) days this week")
                    .font(.subheadline).foregroundStyle(.secondary)
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
                    Text("Consistent — great work!").font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
            }
        }
        .appCard()
    }

    static func calendarCard(last28Days: [CreatineEngine.DayStatus]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Last 28 Days", icon: "calendar", color: .blue)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(last28Days) { day in
                    VStack(spacing: 2) {
                        Text(day.date, format: .dateTime.day())
                            .font(.system(size: 9)).foregroundStyle(.secondary)
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

    static func chartCard(
        data: [CreatineEngine.DailyGrams],
        dailyTargetGrams: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "30-Day Intake", icon: "chart.bar.fill", color: .blue)
            if !data.isEmpty {
                Chart(data) { day in
                    BarMark(x: .value("Day", day.date, unit: .day), y: .value("g", day.grams))
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

    static func recentHistoryCard(entries: [CreatineEntry]) -> some View {
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
                    ForEach(Array(prefixed.enumerated()), id: \.element.persistentModelID) { idx, entry in
                        HStack(spacing: 12) {
                            gradientDisc("pill.fill", color: .blue, size: 32, glyph: 12)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(String(format: "%.0f", entry.grams))g creatine")
                                    .font(.subheadline.weight(.semibold))
                                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        if idx < prefixed.count - 1 { Divider().padding(.leading, 60) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .appCard()
    }

    struct HistorySection: View {
        @Binding var historyRange: CreatineEngine.HistoryRange
        @Binding var scaffoldTimeRange: DetailTimeRange
        let entries: [CreatineEntry]
        let dailyTargetGrams: Double

        var body: some View {
            MetricDetailScaffold(
                navigationTitle: "",
                isLoading: false,
                isEmpty: entries.isEmpty,
                loadingMessage: "",
                emptyIcon: "pill.fill",
                emptyTitle: "No creatine logged yet",
                emptySubtitle: "Log your first dose to see daily history.",
                timeRange: $scaffoldTimeRange,
                segmentColor: .blue,
                showRangePicker: false,
                hero: { EmptyView() },
                content: {
                    historyCard(
                        range: historyRange,
                        entries: entries,
                        dailyTargetGrams: dailyTargetGrams,
                        onSelectRange: { historyRange = $0 }
                    )
                }
            )
        }
    }

    static func historyCard(
        range: CreatineEngine.HistoryRange,
        entries: [CreatineEntry],
        dailyTargetGrams: Double,
        onSelectRange: @escaping (CreatineEngine.HistoryRange) -> Void
    ) -> some View {
        let data = CreatineEngine.dailyGrams(entries: entries, days: range.dayCount)
        let stats = CreatineEngine.historyStats(for: data)

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Daily History", icon: "chart.bar.fill", color: .blue)
            HStack(spacing: 8) {
                ForEach(CreatineEngine.HistoryRange.allCases, id: \.self) { bucket in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { onSelectRange(bucket) }
                    } label: {
                        Text(bucket.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(range == bucket ? Color.blue : Color(.secondarySystemFill), in: Capsule())
                            .foregroundStyle(range == bucket ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            HStack(spacing: 0) {
                historyStatCol("Avg/Day", value: String(format: "%.1fg", stats.avgPerDay))
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 28)
                historyStatCol("Total", value: String(format: "%.0fg", stats.total))
                Rectangle().fill(Color(.separator)).frame(width: 1, height: 28)
                historyStatCol("Days", value: "\(stats.daysTracked)")
            }
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Chart {
                ForEach(data) { point in
                    BarMark(x: .value("Date", point.date, unit: .day), y: .value("g", point.grams))
                        .foregroundStyle(point.grams >= dailyTargetGrams ? Color.blue.gradient : Color.blue.opacity(0.5).gradient)
                        .cornerRadius(4)
                }
                RuleMark(y: .value("Target", dailyTargetGrams))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
                    .foregroundStyle(.blue.opacity(0.4))
            }
            .chartYAxisLabel("g")
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: range.dayCount <= 7 ? 1 : 5)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: range.dayCount <= 7 ? .dateTime.weekday(.abbreviated) : .dateTime.month(.abbreviated).day())
                }
            }
            .frame(height: 180).padding(.vertical, 4)
        }
        .appCard()
    }

    private static func historyStatCol(_ title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.subheadline, design: .rounded, weight: .bold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
