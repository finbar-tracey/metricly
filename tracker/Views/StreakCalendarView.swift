import SwiftUI
import SwiftData

struct StreakCalendarView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate && $0.endTime != nil },
           sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var monthsBack: Int = 6

    private var calendar: Calendar { Calendar.current }

    private var workoutDates: [Date: Int] {
        var counts: [Date: Int] = [:]
        for workout in workouts {
            let day = calendar.startOfDay(for: workout.date)
            counts[day, default: 0] += 1
        }
        return counts
    }

    private var currentStreak: Int {
        let dates = Set(workouts.map { calendar.startOfDay(for: $0.date) })
        var streak = 0
        var day = calendar.startOfDay(for: .now)
        // If no workout today, check yesterday
        if !dates.contains(day) {
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = prev
            if !dates.contains(day) { return 0 }
        }
        while dates.contains(day) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    private var longestStreak: Int {
        let dates = workouts.map { calendar.startOfDay(for: $0.date) }
        let unique = Array(Set(dates)).sorted()
        guard !unique.isEmpty else { return 0 }
        var maxStreak = 1
        var current = 1
        for i in 1..<unique.count {
            if let expected = calendar.date(byAdding: .day, value: 1, to: unique[i-1]),
               calendar.isDate(unique[i], inSameDayAs: expected) {
                current += 1
                maxStreak = max(maxStreak, current)
            } else {
                current = 1
            }
        }
        return maxStreak
    }

    private var thisWeekCount: Int {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= startOfWeek }.count
    }

    private var thisMonthCount: Int {
        let startOfMonth = calendar.dateInterval(of: .month, for: .now)?.start ?? .now
        return workouts.filter { $0.date >= startOfMonth }.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Stats row
                HStack(spacing: 0) {
                    statCard(value: "\(currentStreak)", label: "Current\nStreak", icon: "flame.fill", color: .orange)
                    statCard(value: "\(longestStreak)", label: "Longest\nStreak", icon: "trophy.fill", color: .yellow)
                    statCard(value: "\(thisWeekCount)", label: "This\nWeek", icon: "calendar", color: .blue)
                    statCard(value: "\(thisMonthCount)", label: "This\nMonth", icon: "calendar.badge.clock", color: .green)
                }
                .padding(.horizontal)

                // Contribution grid
                VStack(alignment: .leading, spacing: 8) {
                    Text("Activity")
                        .font(.headline)
                        .padding(.horizontal)

                    contributionGrid
                        .padding(.horizontal)

                    // Legend
                    HStack(spacing: 4) {
                        Text("Less")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        ForEach(0..<5) { level in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForLevel(level))
                                .frame(width: 12, height: 12)
                        }
                        Text("More")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle("Streak")
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var contributionGrid: some View {
        let weeks = generateWeeks()
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                // Day labels
                VStack(spacing: 3) {
                    ForEach(["", "M", "", "W", "", "F", ""], id: \.self) { label in
                        Text(label)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                    }
                }

                ForEach(weeks, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(week, id: \.self) { day in
                            let count = workoutDates[calendar.startOfDay(for: day)] ?? 0
                            let level = intensityLevel(count)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colorForLevel(level))
                                .frame(width: 14, height: 14)
                                .overlay {
                                    if calendar.isDateInToday(day) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .stroke(.primary.opacity(0.4), lineWidth: 1)
                                    }
                                }
                        }
                    }
                }
            }
        }
    }

    private func generateWeeks() -> [[Date]] {
        let today = calendar.startOfDay(for: .now)
        guard let startDate = calendar.date(byAdding: .month, value: -monthsBack, to: today) else { return [] }
        // Align to start of week
        let weekday = calendar.component(.weekday, from: startDate)
        guard let aligned = calendar.date(byAdding: .day, value: -(weekday - calendar.firstWeekday), to: startDate) else { return [] }

        var weeks: [[Date]] = []
        var current = aligned

        while current <= today {
            var week: [Date] = []
            for _ in 0..<7 {
                week.append(current)
                guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
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
        case 0: return .gray.opacity(0.15)
        case 1: return Color.accentColor.opacity(0.25)
        case 2: return Color.accentColor.opacity(0.45)
        case 3: return Color.accentColor.opacity(0.7)
        default: return Color.accentColor
        }
    }
}

#Preview {
    NavigationStack {
        StreakCalendarView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
