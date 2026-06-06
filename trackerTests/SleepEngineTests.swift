import XCTest
@testable import tracker

final class SleepEngineTests: XCTestCase {

    func testAverageSleepEmptyIsZero() {
        XCTAssertEqual(SleepEngine.averageSleep(dailySleep: []), 0)
    }

    func testAverageSleep() {
        let data: [(date: Date, minutes: Double)] = [(.now, 400), (.now, 500)]
        XCTAssertEqual(SleepEngine.averageSleep(dailySleep: data), 450, accuracy: 0.001)
    }

    func testSleepEfficiency() {
        let inBed = Date()
        let wake = inBed.addingTimeInterval(8 * 3600)   // 480 min in bed
        // 432 asleep / 480 in bed = 90%
        XCTAssertEqual(SleepEngine.sleepEfficiency(totalMinutes: 432, inBed: inBed, wakeUp: wake) ?? -1,
                       90, accuracy: 0.001)
    }

    func testSleepEfficiencyNilWithoutTimes() {
        XCTAssertNil(SleepEngine.sleepEfficiency(totalMinutes: 400, inBed: nil, wakeUp: nil))
    }

    func testSleepEfficiencyNilWhenZeroTimeInBed() {
        let t = Date()
        XCTAssertNil(SleepEngine.sleepEfficiency(totalMinutes: 400, inBed: t, wakeUp: t))
    }

    func testSleepScoreLabels() {
        XCTAssertEqual(SleepEngine.sleepScoreLabel(score: 90), "Excellent")
        XCTAssertEqual(SleepEngine.sleepScoreLabel(score: 72), "Good")
        XCTAssertEqual(SleepEngine.sleepScoreLabel(score: 55), "Fair")
        XCTAssertEqual(SleepEngine.sleepScoreLabel(score: 40), "Poor")
    }

    func testAccumulatedDebtHours() {
        // target 480/night; two nights at 420 → 60+60 = 120 min = 2 h
        let details = [
            DailySleepDetail(date: .now, totalMinutes: 420, inBed: nil, wakeUp: nil, stages: []),
            DailySleepDetail(date: .now, totalMinutes: 420, inBed: nil, wakeUp: nil, stages: [])
        ]
        XCTAssertEqual(SleepEngine.accumulatedDebtHours(detailedSleep: details), 2, accuracy: 0.001)
    }

    func testAccumulatedDebtIgnoresSurplus() {
        // a 540-min night is over target → contributes 0, not negative debt
        let details = [
            DailySleepDetail(date: .now, totalMinutes: 540, inBed: nil, wakeUp: nil, stages: []),
            DailySleepDetail(date: .now, totalMinutes: 300, inBed: nil, wakeUp: nil, stages: [])
        ]
        XCTAssertEqual(SleepEngine.accumulatedDebtHours(detailedSleep: details), 3, accuracy: 0.001) // only 300 night
    }

    func testSleepScoreStaysInRange() {
        let stages = [SleepStage(type: .deep, start: Date(), end: Date().addingTimeInterval(90 * 60))]
        let today: (totalMinutes: Double, inBed: Date?, wakeUp: Date?, stages: [SleepStage]) =
            (480, nil, nil, stages)
        let score = SleepEngine.sleepScore(todaySleep: today, detailedSleep: [])
        XCTAssertTrue((0...100).contains(score), "score \(score) out of range")
    }

    func testShiftedMinutesRoundTripsTo11PM() {
        let cal = Calendar.current
        let elevenPM = cal.date(bySettingHour: 23, minute: 0, second: 0, of: .now)!
        let shifted = SleepEngine.shiftedMinutes(elevenPM)
        XCTAssertEqual(SleepEngine.formatShiftedMinutes(shifted), "11 PM")
    }

    func testThisWeekVsLastWeekAverage() {
        let cal = Calendar.current
        let now = Date()
        let weekStart = cal.dateInterval(of: .weekOfYear, for: now)!.start
        let thisWeekDay = weekStart.addingTimeInterval(3600)
        let lastWeekDay = cal.date(byAdding: .day, value: -3, to: weekStart)!
        let data: [(date: Date, minutes: Double)] = [(thisWeekDay, 400), (lastWeekDay, 480)]
        XCTAssertEqual(SleepEngine.thisWeekAverage(dailySleep: data, now: now), 400, accuracy: 0.001)
        XCTAssertEqual(SleepEngine.lastWeekAverage(dailySleep: data, now: now), 480, accuracy: 0.001)
    }
}
