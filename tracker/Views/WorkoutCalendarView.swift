import SwiftUI
import SwiftData

struct WorkoutCalendarView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var workouts: [Workout]

    @State private var displayedMonth = Date.now
    @State private var selectedDate: Date?

    private let calendar = Calendar.current

    private var monthWeeks: [[Date?]] {
        WorkoutCalendarSections.monthData(for: displayedMonth, calendar: calendar)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                WorkoutCalendarSections.calendarCard(
                    displayedMonth: displayedMonth,
                    monthWeeks: monthWeeks,
                    workoutsOn: workoutsOn,
                    calendar: calendar,
                    selectedDate: $selectedDate,
                    onShiftMonth: shiftMonth
                )
                WorkoutCalendarSections.summaryCard(
                    displayedMonth: displayedMonth,
                    workoutsInMonth: workoutsInMonth(displayedMonth),
                    trainingDaysInMonth: trainingDaysInMonth(displayedMonth)
                )
                if let selected = selectedDate {
                    WorkoutCalendarSections.selectedDayCard(
                        selected: selected,
                        dayWorkouts: workoutsOn(selected)
                    )
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

    private func shiftMonth(_ value: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
                displayedMonth = newMonth
                selectedDate = nil
            }
        }
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
