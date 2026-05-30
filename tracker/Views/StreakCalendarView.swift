import SwiftUI
import SwiftData

struct StreakCalendarView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse)
    private var cardioSessions: [CardioSession]

    @State private var monthsBack: Int = 6
    /// Stored as seconds-since-epoch; banner stays hidden for the rest of the calendar day it was dismissed.
    @AppStorage("restDayBannerDismissedAt") private var restDayBannerDismissedAt: Double = 0
    private var restDayDismissed: Bool {
        Calendar.current.isDateInToday(Date(timeIntervalSince1970: restDayBannerDismissedAt))
    }

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

                nextMilestoneCard

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

    // MARK: - Next Milestone

    /// Forward-looking nudge: days to the next streak milestone, plus how
    /// far from beating the all-time best. Hidden when there's no active
    /// streak to build on.
    @ViewBuilder
    private var nextMilestoneCard: some View {
        let milestones = [7, 14, 30, 50, 75, 100, 150, 200, 365]
        if currentStreak >= 1, let next = milestones.first(where: { $0 > currentStreak }) {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Next Milestone", icon: "flag.checkered", color: .orange)
                HStack(alignment: .firstTextBaseline) {
                    Text("\(next)-Day Streak")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(next - currentStreak) to go")
                        .font(.subheadline.bold())
                        .foregroundStyle(.orange)
                        .monospacedDigit()
                }
                GradientProgressBar(value: Double(currentStreak) / Double(next), color: .orange, height: 8)
                if longestStreak > currentStreak {
                    Text("\(longestStreak - currentStreak) more to beat your best of \(longestStreak).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if currentStreak == longestStreak {
                    Text("You're at your all-time best — keep it going!")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .appCard()
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        HeroCard(palette: AppTheme.Gradients.caution) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Current Streak")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            AnimatedInt(
                                value: currentStreak,
                                font: .system(size: 44, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                            Text(currentStreak == 1 ? "day" : "days")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    Spacer()
                    if longestStreak > 0 {
                        VStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.95))
                            Text("\(longestStreak)")
                                .font(.system(size: 18, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                            Text("BEST")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                                .tracking(0.5)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.25), lineWidth: 0.5)
                        )
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(thisWeekCount)", label: "This Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(thisMonthCount)", label: "This Month")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(totalWorkouts)", label: "Total")
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }


    // MARK: - Rest Day Card

    private var restDayCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.indigo, Color(red: 0.40, green: 0.30, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: .indigo.opacity(0.40), radius: 6, y: 3)
                Image(systemName: "bed.double.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Consider a rest day")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("\(currentStreak)-day streak — recovery helps muscles grow.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    restDayBannerDismissedAt = Date.now.timeIntervalSince1970
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .buttonStyle(.pressableCard)
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

    // MARK: - Monthly Breakdown Card

    private var monthlyCard: some View {
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
        case 1: return Color.orange.opacity(0.30)
        case 2: return Color.orange.opacity(0.55)
        case 3: return Color.orange.opacity(0.85)
        default: return Color.orange
        }
    }
}

#Preview {
    NavigationStack { StreakCalendarView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
