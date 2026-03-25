import SwiftUI
import SwiftData

struct WorkoutCalendarView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    @State private var displayedMonth = Date.now
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    monthHeader
                    dayLabels
                    calendarGrid
                }
                .padding(.vertical, 8)
            }

            Section {
                HStack(spacing: 4) {
                    Text("Less")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    ForEach(0...3, id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(heatmapColor(count: level))
                            .frame(width: 14, height: 14)
                    }
                    Text("More")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if let selected = selectedDate {
                let dayWorkouts = workoutsOn(selected)
                if dayWorkouts.isEmpty {
                    Section {
                        Text("No workouts on this day.")
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(selected, format: .dateTime.weekday(.wide).month().day())
                    }
                } else {
                    Section {
                        ForEach(dayWorkouts) { workout in
                            NavigationLink(value: workout) {
                                workoutRow(workout)
                            }
                        }
                    } header: {
                        Text(selected, format: .dateTime.weekday(.wide).month().day())
                    }
                }
            }

            Section {
                HStack {
                    Text("This Month")
                    Spacer()
                    Text("\(workoutsInMonth(displayedMonth))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                HStack {
                    Text("Training Days")
                    Spacer()
                    Text("\(trainingDaysInMonth(displayedMonth))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } header: {
                Text("Summary")
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
    }

    // MARK: - Month Header

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(-1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.bold())
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(displayedMonth, format: .dateTime.month(.wide).year())
                .font(.title3.bold())

            Spacer()

            Button {
                shiftMonth(1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.title3.bold())
            }
            .accessibilityLabel("Next month")
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Day Labels

    private var dayLabels: some View {
        HStack(spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        let weeks = monthData()
        return VStack(spacing: 8) {
            ForEach(0..<weeks.count, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<7, id: \.self) { col in
                        if let date = weeks[row][col] {
                            dayCell(date)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                        }
                    }
                }
            }
        }
    }

    private func workoutCount(on date: Date) -> Int {
        workoutsOn(date).count
    }

    private func heatmapColor(count: Int) -> Color {
        switch count {
        case 0: return Color(.systemFill).opacity(0.3)
        case 1: return Color.accentColor.opacity(0.35)
        case 2: return Color.accentColor.opacity(0.6)
        default: return Color.accentColor.opacity(0.9)
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isToday = calendar.isDateInToday(date)
        let count = workoutCount(on: date)
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayNum = calendar.component(.day, from: date)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedDate = date
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor)
                        .frame(width: 36, height: 36)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(count > 0 ? heatmapColor(count: count) : .clear)
                        .frame(width: 36, height: 36)
                }

                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 36, height: 36)
                }

                Text("\(dayNum)")
                    .font(.subheadline.weight(count > 0 ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 42)
        .accessibilityLabel("\(dayNum), \(count) workout\(count == 1 ? "" : "s")\(isToday ? ", today" : "")")
    }

    // MARK: - Workout Row

    private func workoutRow(_ workout: Workout) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workout.name)
                .font(.headline)
            HStack(spacing: 8) {
                Text("\(workout.exercises.count) exercises")
                if let duration = workout.formattedDuration {
                    Text("·")
                    Text(duration)
                }
                if let rating = workout.rating, rating > 0 {
                    Text("·")
                    HStack(spacing: 1) {
                        ForEach(1...rating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .imageScale(.small)
                        }
                    }
                    .foregroundStyle(.yellow)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func shiftMonth(_ value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
                selectedDate = nil
            }
        }
    }

    private func monthData() -> [[Date?]] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth))
        else { return [] }

        // Monday = 1 in ISO, Sunday = 7
        var weekday = calendar.component(.weekday, from: firstOfMonth)
        // Convert to Monday-based: Mon=0, Tue=1, ..., Sun=6
        weekday = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                days.append(date)
            }
        }

        // Pad to fill last week
        while days.count % 7 != 0 {
            days.append(nil)
        }

        // Convert flat array to weeks
        var weeks: [[Date?]] = []
        for i in stride(from: 0, to: days.count, by: 7) {
            weeks.append(Array(days[i..<min(i + 7, days.count)]))
        }
        return weeks
    }

    private var workoutDays: Set<DateComponents> {
        Set(workouts.map { calendar.dateComponents([.year, .month, .day], from: $0.date) })
    }

    private func hasWorkout(on date: Date) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return workoutDays.contains(comps)
    }

    private func workoutsOn(_ date: Date) -> [Workout] {
        workouts.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    private func workoutsInMonth(_ month: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return 0 }
        return workouts.filter { $0.date >= interval.start && $0.date < interval.end }.count
    }

    private func trainingDaysInMonth(_ month: Date) -> Int {
        guard let interval = calendar.dateInterval(of: .month, for: month) else { return 0 }
        let monthWorkouts = workouts.filter { $0.date >= interval.start && $0.date < interval.end }
        return Set(monthWorkouts.map { calendar.startOfDay(for: $0.date) }).count
    }
}
