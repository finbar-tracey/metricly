import XCTest
@testable import tracker

final class SmartSuggestionsEngineTests: XCTestCase {

    func testRecentExerciseNamesEmptyWhenNoWorkouts() {
        XCTAssertTrue(SmartSuggestionsEngine.recentExerciseNames(days: 7, in: []).isEmpty)
    }

    func testExercisesForGroupFallbackNames() {
        let names = SmartSuggestionsEngine.exercisesForGroup(.chest, workouts: [])
        XCTAssertFalse(names.isEmpty)
    }

    func testReasonForGroupUsesCalendarDayDifference() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14 22:13 UTC
        // 23:50 the previous day is only ~22h earlier but is "yesterday".
        let lastTrained = cal.startOfDay(for: now).addingTimeInterval(-600)
        let recovery = RecoveryResult(
            readinessScore: 1,
            muscleResults: [MuscleFatigueResult(group: .chest, freshness: 1, lastTrained: lastTrained, effectiveRecoveryHours: 48)],
            suggestedWorkoutType: "Anything"
        )
        XCTAssertEqual(SmartSuggestionsEngine.reasonForGroup(.chest, recovery: recovery, now: now, calendar: cal),
                       "Last trained yesterday")
    }
}
