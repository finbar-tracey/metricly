import XCTest
@testable import tracker

@MainActor
final class WorkoutIntervalTimerControllerTests: XCTestCase {

    func testForegroundSyncFinishesWhenOverallExpired() {
        let controller = WorkoutIntervalTimerController()
        let past = Date(timeIntervalSinceNow: -10)
        controller.applyTimingForTesting(
            mode: .amrap,
            overallEnd: past,
            phaseEnd: past,
            totalTime: 60,
            timeRemaining: 0
        )
        controller.syncOnReturnToForeground()
        XCTAssertFalse(controller.isRunning)
    }

    func testForegroundSyncRecalculatesAMRAPRemaining() {
        let controller = WorkoutIntervalTimerController()
        let overallEnd = Date(timeIntervalSinceNow: 120)
        let phaseEnd = overallEnd
        controller.applyTimingForTesting(
            mode: .amrap,
            overallEnd: overallEnd,
            phaseEnd: phaseEnd,
            totalTime: 300,
            timeRemaining: 300
        )
        controller.syncOnReturnToForeground()
        XCTAssertTrue(controller.isRunning)
        XCTAssertGreaterThan(controller.timeRemaining, 0)
        XCTAssertLessThanOrEqual(controller.timeRemaining, 300)
    }

    func testEMOMStartSetsRoundAndInterval() {
        let controller = WorkoutIntervalTimerController()
        controller.mode = .emom
        controller.emomMinutes = 2
        controller.emomIntervalSeconds = 60
        controller.start()
        XCTAssertTrue(controller.isRunning)
        XCTAssertEqual(controller.currentRound, 1)
        XCTAssertEqual(controller.timeRemaining, 60)
        XCTAssertEqual(controller.totalRounds, 2)
        controller.stop()
    }

    func testEMOMRecalculatesRoundAfterBackground() {
        let controller = WorkoutIntervalTimerController()
        controller.mode = .emom
        controller.emomIntervalSeconds = 60
        controller.applyTimingForTesting(
            mode: .emom,
            overallEnd: Date(timeIntervalSinceNow: 300),
            phaseEnd: Date(timeIntervalSinceNow: 25),
            totalTime: 300,
            timeRemaining: 25,
            currentRound: 1,
            totalRounds: 5
        )
        controller.syncOnReturnToForeground()
        XCTAssertTrue(controller.isRunning)
        XCTAssertGreaterThanOrEqual(controller.currentRound, 1)
        XCTAssertLessThanOrEqual(controller.timeRemaining, 60)
    }
}
