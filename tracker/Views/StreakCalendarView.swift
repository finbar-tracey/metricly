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
            if let expected = cal.date(byAdding: .day, value: 1, to: unique[i - 1]),
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
            let end = cal.dateInterval(of: .month, for: date)?.end ?? date
            let count = workouts.filter { $0.date >= start && $0.date < end }.count
                      + cardioSessions.filter { $0.date >= start && $0.date < end }.count
            let label = date.formatted(.dateTime.month(.abbreviated))
            return (label, count)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                StreakCalendarSections.heroCard(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    thisWeekCount: thisWeekCount,
                    thisMonthCount: thisMonthCount,
                    totalWorkouts: totalWorkouts
                )

                StreakCalendarSections.nextMilestoneCard(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak
                )

                if currentStreak >= 7 && !restDayDismissed {
                    StreakCalendarSections.restDayCard(currentStreak: currentStreak) {
                        restDayBannerDismissedAt = Date.now.timeIntervalSince1970
                    }
                }

                StreakCalendarSections.activityGridCard(
                    activeDates: activeDates,
                    monthsBack: monthsBack
                )

                StreakCalendarSections.monthlyCard(monthlyBreakdown: monthlyBreakdown)

                StreakCalendarSections.statsCard(
                    currentStreak: currentStreak,
                    longestStreak: longestStreak,
                    thisWeekCount: thisWeekCount,
                    thisMonthCount: thisMonthCount
                )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Streak")
    }
}

#Preview {
    NavigationStack { StreakCalendarView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
