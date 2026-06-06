import SwiftUI
import Charts

enum WaterTrackerCardSections {

    static func heroCard(todayTotalMl: Double, goalMl: Double, progress: Double) -> some View {
        HeroCard(palette: [
            Color.cyan,
            Color(red: 0.20, green: 0.62, blue: 0.92),
            Color(red: 0.30, green: 0.40, blue: 0.95)
        ]) {
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
                            .shadow(color: .white.opacity(0.5), radius: 6, y: 1)
                    }
                    .frame(width: 68, height: 68)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            AnimatedInt(
                                value: Int(todayTotalMl),
                                font: .system(size: 48, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                            Text("ml")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                        Text("of \(Int(goalMl)) ml goal")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                    }
                }

                if progress >= 1.0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.caption.bold())
                        Text("Goal Reached!")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                } else {
                    Text("\(Int(goalMl - todayTotalMl)) ml remaining")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.22), lineWidth: 0.5))
                }

                GradientProgressBar(value: progress, color: .white, height: 8)
            }
            .padding(20)
        }
    }

    static func quickAddCard(
        customMl: Binding<String>,
        isMlFocused: FocusState<Bool>.Binding,
        onAdd: @escaping (Double) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Log Water", icon: "drop.fill", color: .cyan)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(WaterEntry.presets, id: \.label) { preset in
                        Button { onAdd(preset.ml) } label: {
                            VStack(spacing: 6) {
                                gradientDisc(preset.icon, color: .cyan, size: 40, glyph: 17)
                                Text(preset.label)
                                    .font(.caption2.weight(.medium))
                                Text("\(Int(preset.ml)) ml")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 72)
                            .padding(.vertical, 10)
                            .background(Color(.secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
            }

            HStack(spacing: 12) {
                gradientDisc("pencil", color: .cyan, size: 36, glyph: 13)
                TextField("Custom amount", text: customMl)
                    .keyboardType(.numberPad)
                    .focused(isMlFocused)
                Text("ml")
                    .foregroundStyle(.secondary)
                Button {
                    if let ml = Double(customMl.wrappedValue), ml > 0 {
                        onAdd(ml)
                        customMl.wrappedValue = ""
                        isMlFocused.wrappedValue = false
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                }
                .accessibilityLabel("Add water")
                .disabled(Double(customMl.wrappedValue) ?? 0 <= 0)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    static func statsCard(
        timeRange: DetailTimeRange,
        stats: (avg: Double, daysMetGoal: Int, totalDays: Int),
        hydrationStreak: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
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

    static func streakCard(hydrationStreak: Int) -> some View {
        HStack(spacing: 14) {
            gradientDisc(
                hydrationStreak >= 7 ? "drop.circle.fill" : "drop.fill",
                color: .cyan,
                size: 50,
                glyph: 21
            )
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

    static func timeOfDayCard(blocks: [WaterTrackerDataSections.TimeBlock]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Hydration by Time of Day", icon: "clock.fill", color: .cyan)

            HStack(spacing: 8) {
                ForEach(blocks) { block in
                    VStack(spacing: 6) {
                        if block.ml > 0 {
                            gradientDisc(block.icon, color: block.color, size: 36, glyph: 14)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemFill))
                                    .frame(width: 36, height: 36)
                                Image(systemName: block.icon)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
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
                    .background(block.ml > 0 ? block.color.opacity(0.06) : Color.clear, in: RoundedRectangle(cornerRadius: AppTheme.chipRadius))
                }
            }
        }
        .appCard()
    }

    static func chartCard(
        timeRange: DetailTimeRange,
        totals: [(date: Date, ml: Double)],
        goalMl: Double,
        onSelectRange: @escaping (DetailTimeRange) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "History", icon: "chart.bar.fill", color: .cyan)

            HStack(spacing: 6) {
                ForEach(DetailTimeRange.allCases, id: \.self) { range in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { onSelectRange(range) }
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

    static func todayLogCard(todayEntries: [WaterEntry]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Today's Entries", icon: "list.bullet", color: .secondary)

            VStack(spacing: 0) {
                ForEach(Array(todayEntries.enumerated()), id: \.element.id) { idx, entry in
                    HStack(spacing: 12) {
                        gradientDisc("drop.fill", color: .cyan, size: 32, glyph: 12)
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
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    private static func statColumn(value: String, label: String, color: Color) -> some View {
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
}
