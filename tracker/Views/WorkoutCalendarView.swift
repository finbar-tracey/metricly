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
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                calendarCard
                summaryCard
                if let selected = selectedDate {
                    selectedDayCard(selected)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Workout.self) { workout in
            WorkoutDetailView(workout: workout)
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(spacing: 16) {
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shiftMonth(-1)
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.20), Color.accentColor.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(Color.accentColor.opacity(0.22), lineWidth: 0.5))
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.pressableCard).accessibilityLabel("Previous month")

                Spacer()
                Text(displayedMonth, format: .dateTime.month(.wide).year())
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(0.3)
                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    shiftMonth(1)
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.20), Color.accentColor.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 38, height: 38)
                            .overlay(Circle().stroke(Color.accentColor.opacity(0.22), lineWidth: 0.5))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .buttonStyle(.pressableCard).accessibilityLabel("Next month")
            }

            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day).font(.caption2.bold()).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }

            calendarGrid

            HStack(spacing: 6) {
                Spacer()
                Text("Less").font(.caption2).foregroundStyle(.secondary)
                ForEach(0...3, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3).fill(heatmapColor(count: level)).frame(width: 14, height: 14)
                }
                Text("More").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .appCard()
    }

    // MARK: - Summary Card

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "This Month", icon: "calendar.badge.checkmark", color: .accentColor)
            HStack(spacing: 12) {
                summaryTile("Workouts", value: "\(workoutsInMonth(displayedMonth))", icon: "dumbbell.fill", color: .accentColor)
                summaryTile("Training Days", value: "\(trainingDaysInMonth(displayedMonth))", icon: "calendar", color: .green)
            }
        }
        .appCard()
    }

    private func summaryTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.system(size: 20, weight: .black, design: .rounded).monospacedDigit())
                Text(title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .tracking(0.3)
                    .textCase(.uppercase)
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
        .frame(maxWidth: .infinity)
    }

    // MARK: - Selected Day Card

    private func selectedDayCard(_ selected: Date) -> some View {
        let dayWorkouts = workoutsOn(selected)
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: selected.formatted(.dateTime.weekday(.wide).month().day()),
                icon: "calendar",
                color: .accentColor
            )

            if dayWorkouts.isEmpty {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Color(.secondarySystemFill)).frame(width: 40, height: 40)
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 16, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    Text("No workouts on this day.").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dayWorkouts.enumerated()), id: \.element.persistentModelID) { idx, workout in
                        NavigationLink(value: workout) {
                            workoutRow(workout)
                        }
                        .buttonStyle(.plain)
                        if idx < dayWorkouts.count - 1 { Divider().padding(.leading, 64) }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .appCard()
    }

    private func workoutRow(_ workout: Workout) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(workout.name).font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text("\(workout.exercises.count) exercises")
                    if let duration = workout.formattedDuration {
                        Text("·"); Text(duration)
                    }
                    if let rating = workout.rating, rating > 0 {
                        Text("·")
                        HStack(spacing: 1) {
                            ForEach(1...rating, id: \.self) { _ in
                                Image(systemName: "star.fill").imageScale(.small)
                            }
                        }
                        .foregroundStyle(.yellow)
                    }
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
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
                            Color.clear.frame(maxWidth: .infinity).frame(height: 42)
                        }
                    }
                }
            }
        }
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
        let count = workoutsOn(date).count
        let isSelected = selectedDate.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let dayNum = calendar.component(.day, from: date)

        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                let alreadySelected = selectedDate.map { calendar.isDate(date, inSameDayAs: $0) } ?? false
                selectedDate = alreadySelected ? nil : date
            }
        } label: {
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.accentColor.opacity(0.50), radius: 6, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(count > 0 ? heatmapColor(count: count) : .clear)
                        .frame(width: 38, height: 38)
                }
                if isToday && !isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(width: 38, height: 38)
                }
                Text("\(dayNum)")
                    .font(.system(size: 14, weight: count > 0 ? .bold : .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(isSelected ? .white : isToday ? Color.accentColor : .primary)
            }
        }
        .buttonStyle(.pressableCard)
        .frame(maxWidth: .infinity).frame(height: 44)
        .accessibilityLabel("\(dayNum), \(count) workout\(count == 1 ? "" : "s")\(isToday ? ", today" : "")")
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

        var weekday = calendar.component(.weekday, from: firstOfMonth)
        weekday = (weekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: weekday)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) { days.append(date) }
        }
        while days.count % 7 != 0 { days.append(nil) }

        var weeks: [[Date?]] = []
        for i in stride(from: 0, to: days.count, by: 7) {
            weeks.append(Array(days[i..<min(i + 7, days.count)]))
        }
        return weeks
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
