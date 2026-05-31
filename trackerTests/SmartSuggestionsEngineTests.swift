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
}
