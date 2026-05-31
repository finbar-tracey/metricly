import XCTest
@testable import tracker

final class WeeklyMonthlyReportEngineTests: XCTestCase {

    private let calendar = Calendar.current

    func testMonthPeriodRangeStartsOnFirstOfMonth() {
        let june4 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4, hour: 12))!
        let range = WeeklyMonthlyReportEngine.periodRange(period: .month, calendar: calendar, now: june4)
        let monthStart = calendar.dateInterval(of: .month, for: june4)!.start
        XCTAssertEqual(range.start, monthStart)
        XCTAssertEqual(range.end, june4)
    }

    func testPreviousMonthRangeEndsAtCurrentMonthStart() {
        let june4 = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))!
        let current = WeeklyMonthlyReportEngine.periodRange(period: .month, calendar: calendar, now: june4)
        let previous = WeeklyMonthlyReportEngine.previousPeriodRange(
            period: .month, currentStart: current.start, calendar: calendar
        )
        XCTAssertEqual(previous.end, current.start)
        let mayStart = calendar.date(from: DateComponents(year: 2026, month: 5, day: 1))!
        XCTAssertEqual(previous.start, mayStart)
    }

    func testWeekPeriodRangeStartsOnWeekOfYear() {
        var comps = DateComponents(year: 2026, month: 6, day: 4, hour: 12)
        let wednesday = calendar.date(from: comps)!
        let range = WeeklyMonthlyReportEngine.periodRange(period: .week, calendar: calendar, now: wednesday)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: wednesday)!.start
        XCTAssertEqual(range.start, weekStart)
        XCTAssertEqual(range.end, wednesday)
    }

    func testPreviousWeekRangeEndsAtCurrentStart() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4))!
        let current = WeeklyMonthlyReportEngine.periodRange(period: .week, calendar: calendar, now: now)
        let previous = WeeklyMonthlyReportEngine.previousPeriodRange(period: .week, currentStart: current.start, calendar: calendar)
        XCTAssertEqual(previous.end, current.start)
        XCTAssertEqual(calendar.dateComponents([.day], from: previous.start, to: previous.end).day, 7)
    }

    func testEmptyHistorySnapshot() {
        let snapshot = WeeklyMonthlyReportEngine.make(
            WeeklyMonthlyReportEngine.Inputs(
                period: .week,
                allWorkouts: [],
                cardioSessions: [],
                bodyWeightEntries: []
            )
        )
        XCTAssertEqual(snapshot.workoutCount, 0)
        XCTAssertEqual(snapshot.totalSets, 0)
        XCTAssertEqual(snapshot.totalVolumeKg, 0)
        XCTAssertEqual(snapshot.prsHitCount, 0)
        XCTAssertEqual(snapshot.vibeEmoji, "😴")
        XCTAssertTrue(snapshot.periodWorkoutsEmpty)
    }

    func testVolumeChangeVersusPreviousWeek() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 4, hour: 12))!
        let currentStart = calendar.dateInterval(of: .weekOfYear, for: now)!.start
        let previousRange = WeeklyMonthlyReportEngine.previousPeriodRange(
            period: .week, currentStart: currentStart, calendar: calendar
        )
        let prevDate = calendar.date(byAdding: .day, value: -1, to: previousRange.end)!

        let currentWorkout = Workout(name: "A", date: now)
        let currentEx = Exercise(name: "Squat", workout: currentWorkout, category: .legs)
        currentEx.sets.append(ExerciseSet(reps: 5, weight: 100, exercise: currentEx))
        currentWorkout.exercises.append(currentEx)

        let prevWorkout = Workout(name: "B", date: prevDate)
        let prevEx = Exercise(name: "Squat", workout: prevWorkout, category: .legs)
        prevEx.sets.append(ExerciseSet(reps: 5, weight: 50, exercise: prevEx))
        prevWorkout.exercises.append(prevEx)

        let snapshot = WeeklyMonthlyReportEngine.make(
            WeeklyMonthlyReportEngine.Inputs(
                period: .week,
                allWorkouts: [currentWorkout, prevWorkout],
                cardioSessions: [],
                bodyWeightEntries: [],
                referenceDate: now
            )
        )

        XCTAssertEqual(snapshot.workoutCount, 1)
        XCTAssertEqual(snapshot.totalVolumeKg, 500, accuracy: 0.01)
        XCTAssertNotNil(snapshot.volumeChange)
        XCTAssertGreaterThan(snapshot.volumeChange!, 0)
    }
}
