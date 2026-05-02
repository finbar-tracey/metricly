import SwiftUI
import SwiftData

struct StreakCalendarView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse)
    private var cardioSessions: [CardioSession]

    @State private var monthsBack: Int = 6
    @State private var restDayDismissed = false

    private var cal: Calendar { Calendar.current }

    /// All active days (workouts + cardio) — value = total session count for heat-map intensity
    private var activeDates: [Date: Int] {
        var counts: [Date: Int] = [:]
        for workout in workouts {
            let day = cal.startOfDay(for: workout.date)
            counts[day, default: 0] += 1
        }
        for session in cardioSessions {
            let day = cal.startOfDay(for: session.date)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private var currentStreak: Int {
        Workout.currentStreak(from: workouts, cardioSessions: cardioSessions)
    }

    private var longestStreak: Int {
        let unique = Array(activeDates.keys).sorted()
        guard !unique.isEmpty else { return 0 }
        var maxStreak = 1
        var current = 1
        for i in 1..<unique.count {
            if let expected = cal.date(byAdding: .day, value: 1, to: unique[i-1]),
               cal.isDate(unique[i], inSameDayAs: expected) {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 1
            }
        }
        return maxStreak
    }

    private var thisWeekCount: Int {
        let start = cal.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= start }.count
             + cardioSessions.filter { $0.date >= start }.count
    }

    private var thisMonthCount: Int {
        let start = cal.dateInterval(of: .month, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= start }.count
             + cardioSessions.filter { $0.date >= start }.count
    }

    private var totalWorkouts: Int { workouts.count + cardioSessions.count }

    private var monthlyBreakdown: [(label: String, count: Int)] {
        (0..<6).reversed().map { offset in
            let date = cal.date(byAdding: .month, value: -offset, to: .now) ?? .now
            let start = cal.dateInterval(of: .month, for: date)?.start ?? date
            let end   = cal.dateInterval(of: .month, for: date)?.end ?? date
            let count = workouts.filter { $0.date >= start && $0.date < end }.count
                      + cardioSessions.filter { $0.date >= start && $0.date < end }.count
            let label = date.formatted(.dateTime.month(.abbreviated))
            return (label, count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                heroCard

                if currentStreak >= 7 && !restDayDismissed {
                    restDayCard
                }

                activityGridCard

                monthlyCard

                statsCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Streak")
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: [Color.orange, Color.red.opacity(0.75)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 52, height: 52)
                        Image(systemName: "flame.fill")
                            .font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Current Streak")
                            .font(.caption.weight(.semibold)).foregroundStyle(.white.opacity(0.75))
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(currentStreak)")
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .foregroundStyle(.white).monospacedDigit()
                            Text(currentStreak == 1 ? "day" : "days")
                                .font(.subheadline.weight(.medium)).foregroundStyle(.white.opacity(0.75))
                        }
                    }
                    Spacer()
                    if longestStreak > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "trophy.fill").font(.caption.bold()).foregroundStyle(.white.opacity(0.9))
                            Text("\(longestStreak)").font(.title3.bold()).foregroundStyle(.white).monospacedDigit()
                            Text("best").font(.caption2).foregroundStyle(.white.opacity(0.70))
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 12))
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(thisWeekCount)", label: "This Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(thisMonthCount)", label: "This Month")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(totalWorkouts)", label: "Total")
                }
            }
            .padding(20)
        }
        .heroCard()
    }


    // MARK: - Rest Day Card

    private var restDayCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 48, height: 48)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Consider a rest day").font(.subheadline.weight(.semibold))
                Text("\(currentStreak)-day streak — recovery helps muscles grow.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { restDayDismissed = true }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20)).foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(.plain)
        }
        .appCard()
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Activity Grid Card

    private var activityGridCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Activity", icon: "square.grid.3x3.fill", color: .orange)

            contributionGrid

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

    private var contributionGrid: some View {
        let weeks = generateWeeks()
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

                ForEach(Array(weeks.enumerated()), id: \.offset) { idx, week in
                    VStack(spacing: 3) {
                        ForEach(week, id: \.self) { day in
                            let count = activeDates[cal.startOfDay(for: day)] ?? 0
                            let level = intensityLevel(count)
                            let isFuture = day > cal.startOfDay(for: .now)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(isFuture ? Color.clear : colorForLevel(level))
                                .frame(width: 14, height: 14)
                                .overlay {
                                    if cal.isDateInToday(day) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(Color.orange, lineWidth: 1.5)
                                    } else if !isFuture && level == 0 {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Monthly Breakdown Card

    private var monthlyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Monthly Activity", icon: "calendar.badge.clock", color: .orange)

            let maxCount = monthlyBreakdown.map(\.count).max() ?? 1

            VStack(spacing: 0) {
                ForEach(Array(monthlyBreakdown.enumerated()), id: \.offset) { idx, month in
                    HStack(spacing: 12) {
                        Text(month.label)
                            .font(.subheadline.weight(.medium))
                            .frame(width: 36, alignment: .leading)
                        GeometryReader { geo in
                            let width = maxCount > 0 ? geo.size.width * CGFloat(month.count) / CGFloat(maxCount) : 0
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.orange.opacity(0.10))
                                    .frame(maxWidth: .infinity)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [Color.orange, Color.red.opacity(0.7)],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(width, month.count > 0 ? 4 : 0))
                            }
                        }
                        .frame(height: 20)
                        Text("\(month.count)")
                            .font(.subheadline.bold().monospacedDigit())
                            .frame(width: 24, alignment: .trailing)
                            .foregroundStyle(month.count == 0 ? .tertiary : .primary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if idx < monthlyBreakdown.count - 1 { Divider().padding(.leading, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    // MARK: - Stats Card

    private var statsCard: some View {
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

    private func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold().monospacedDigit())
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Helpers

    private func generateWeeks() -> [[Date]] {
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

    private func intensityLevel(_ count: Int) -> Int {
        switch count {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        case 3: return 3
        default: return 4
        }
    }

    private func colorForLevel(_ level: Int) -> Color {
        switch level {
        case 0: return Color(.systemFill)
        case 1: return Color.orange.opacity(0.25)
        case 2: return Color.orange.opacity(0.45)
        case 3: return Color.orange.opacity(0.70)
        default: return Color.orange
        }
    }
}

#Preview {
    NavigationStack { StreakCalendarView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
