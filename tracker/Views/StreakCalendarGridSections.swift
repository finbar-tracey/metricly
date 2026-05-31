import SwiftUI

enum StreakCalendarGridSections {

    // MARK: - Activity Grid

    static func activityGridCard(
        activeDates: [Date: Int],
        monthsBack: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Activity", icon: "square.grid.3x3.fill", color: .orange)

            contributionGrid(activeDates: activeDates, monthsBack: monthsBack)

            HStack(spacing: 6) {
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach(0..<5) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForLevel(level))
                        .frame(width: 12, height: 12)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    // MARK: - Monthly

    static func monthlyCard(monthlyBreakdown: [(label: String, count: Int)]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Activity", icon: "calendar.badge.clock", color: .orange)

            let maxCount = monthlyBreakdown.map(\.count).max() ?? 1

            VStack(spacing: 0) {
                ForEach(Array(monthlyBreakdown.enumerated()), id: \.offset) { idx, month in
                    HStack(spacing: 12) {
                        Text(month.label.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .frame(width: 40, alignment: .leading)
                            .foregroundStyle(.secondary)
                        GeometryReader { geo in
                            let width = maxCount > 0 ? geo.size.width * CGFloat(month.count) / CGFloat(maxCount) : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(Color.orange.opacity(0.12))
                                    .frame(maxWidth: .infinity)
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.orange, Color(red: 0.85, green: 0.30, blue: 0.20)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                                            .stroke(.white.opacity(0.20), lineWidth: 0.5)
                                    )
                                    .frame(width: max(width, month.count > 0 ? 5 : 0))
                                    .shadow(color: Color.orange.opacity(0.40), radius: 4, y: 1)
                            }
                        }
                        .frame(height: 22)
                        Text("\(month.count)")
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .frame(width: 26, alignment: .trailing)
                            .foregroundStyle(month.count == 0 ? Color.secondary : Color.orange)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < monthlyBreakdown.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
        }
        .appCard()
    }

    // MARK: - Stats

    static func statsCard(
        currentStreak: Int,
        longestStreak: Int,
        thisWeekCount: Int,
        thisMonthCount: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All-Time Stats", icon: "chart.bar.fill", color: .orange)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                statTile("Current Streak", value: "\(currentStreak) days", icon: "flame.fill", color: .orange)
                statTile("Longest Streak", value: "\(longestStreak) days", icon: "trophy.fill", color: .yellow)
                statTile("This Week", value: "\(thisWeekCount)", icon: "calendar", color: .blue)
                statTile("This Month", value: "\(thisMonthCount)", icon: "calendar.badge.clock", color: .green)
            }
        }
        .appCard()
    }

    // MARK: - Private helpers

    private static func contributionGrid(
        activeDates: [Date: Int],
        monthsBack: Int
    ) -> some View {
        let cal = Calendar.current
        let weeks = generateWeeks(cal: cal, monthsBack: monthsBack)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 3) {
                VStack(spacing: 3) {
                    ForEach(["", "M", "", "W", "", "F", ""], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                    }
                }

                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    VStack(spacing: 3) {
                        ForEach(week, id: \.self) { day in
                            let count = activeDates[cal.startOfDay(for: day)] ?? 0
                            let level = intensityLevel(count)
                            let isFuture = day > cal.startOfDay(for: .now)
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(isFuture ? Color.clear : colorForLevel(level))
                                .frame(width: 15, height: 15)
                                .shadow(
                                    color: level >= 3 ? Color.orange.opacity(0.45) : .clear,
                                    radius: 3, y: 1
                                )
                                .overlay {
                                    if cal.isDateInToday(day) {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .stroke(Color.orange, lineWidth: 2)
                                    } else if !isFuture && level == 0 {
                                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                                            .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    private static func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .shadow(color: color.opacity(0.40), radius: 5, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }

    private static func generateWeeks(cal: Calendar, monthsBack: Int) -> [[Date]] {
        let today = cal.startOfDay(for: .now)
        guard let startDate = cal.date(byAdding: .month, value: -monthsBack, to: today) else { return [] }
        let weekday = cal.component(.weekday, from: startDate)
        guard let aligned = cal.date(byAdding: .day, value: -(weekday - cal.firstWeekday), to: startDate) else { return [] }

        var weeks: [[Date]] = []
        var current = aligned

        while current <= today {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(current)
                guard let next = cal.date(byAdding: .day, value: 1, to: current) else { break }
                current = next
            }
            weeks.append(week)
        }
        return weeks
    }

    private static func intensityLevel(_ count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }

    private static func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color(.systemFill)
        case 1: return Color.orange.opacity(0.30)
        case 2: return Color.orange.opacity(0.55)
        case 3: return Color.orange.opacity(0.85)
        default: return Color.orange
        }
    }
}
