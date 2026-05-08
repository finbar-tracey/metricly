import XCTest
@testable import tracker

final class StreakTests: XCTestCase {

    private let cal = Calendar.current

    // MARK: - Empty / sparse

    func testEmptyInputReturnsZero() {
        XCTAssertEqual(Workout.currentStreak(from: [], cardioSessions: []), 0)
    }

    func testFutureWorkoutsDoNotCount() {
        let future = makeWorkout(daysFromToday: 3)
        XCTAssertEqual(Workout.currentStreak(from: [future]), 0)
    }

    // MARK: - Basic counting

    func testSingleWorkoutToday() {
        let today = makeWorkout(daysFromToday: 0)
        XCTAssertEqual(Workout.currentStreak(from: [today]), 1)
    }

    func testTodayPlusYesterday() {
        let workouts = [
            makeWorkout(daysFromToday: 0),
            makeWorkout(daysFromToday: -1),
        ]
        XCTAssertEqual(Workout.currentStreak(from: workouts), 2)
    }

    func testFiveDayStreakEndingToday() {
        let workouts = (0...4).map { makeWorkout(daysFromToday: -$0) }
        XCTAssertEqual(Workout.currentStreak(from: workouts), 5)
    }

    // MARK: - Yesterday-only (today not yet trained)

    func testStreakContinuesIfTrainedYesterdayButNotToday() {
        // Trained yesterday + day before — should report 2, the streak isn't broken
        // until you skip a full day after yesterday.
        let workouts = [
            makeWorkout(daysFromToday: -1),
            makeWorkout(daysFromToday: -2),
            makeWorkout(daysFromToday: -3),
        ]
        XCTAssertEqual(Workout.currentStreak(from: workouts), 3)
    }

    // MARK: - Gaps

    func testGapBreaksStreak() {
        // Today + 4 days ago — gap of 3 days breaks it, streak is just today
        let workouts = [
            makeWorkout(daysFromToday: 0),
            makeWorkout(daysFromToday: -4),
            makeWorkout(daysFromToday: -5),
        ]
        XCTAssertEqual(Workout.currentStreak(from: workouts), 1)
    }

    func testStreakReturnsZeroWhenLastActiveTooLongAgo() {
        // Last active 3 days ago — streak is 0
        let workouts = [makeWorkout(daysFromToday: -3)]
        XCTAssertEqual(Workout.currentStreak(from: workouts), 0)
    }

    // MARK: - Cardio counts as active

    func testCardioCountsAsActiveDay() {
        let workout = makeWorkout(daysFromToday: 0)
        let cardio = makeCardio(daysFromToday: -1)
        XCTAssertEqual(
            Workout.currentStreak(from: [workout], cardioSessions: [cardio]),
            2
        )
    }

    func testCardioOnlyStreak() {
        let cardio = (0...2).map { makeCardio(daysFromToday: -$0) }
        XCTAssertEqual(
            Workout.currentStreak(from: [], cardioSessions: cardio),
            3
        )
    }

    // MARK: - Duplicates collapse to one day

    func testTwoSessionsSameDayCountAsOne() {
        // Same calendar day — should not double-count
        let earlier = makeWorkout(daysFromToday: 0, hour: 7)
        let later   = makeWorkout(daysFromToday: 0, hour: 19)
        XCTAssertEqual(Workout.currentStreak(from: [earlier, later]), 1)
    }

    // MARK: - Helpers

    private func makeWorkout(daysFromToday: Int, hour: Int = 12) -> Workout {
        let base = cal.date(byAdding: .day, value: daysFromToday, to: .now)!
        let date = cal.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        let w = Workout(name: "Test", date: date)
        w.endTime = date.addingTimeInterval(3600)
        return w
    }

    private func makeCardio(daysFromToday: Int) -> CardioSession {
        let date = cal.date(byAdding: .day, value: daysFromToday, to: .now)!
        return CardioSession(date: date)
    }
}
