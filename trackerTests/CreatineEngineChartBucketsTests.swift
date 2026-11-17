import XCTest
@testable import tracker

final class CreatineEngineChartBucketsTests: XCTestCase {

    private let calendar = Calendar.current
    private static let fixedNow = Date(timeIntervalSince1970: 1_700_000_000)

    func testDailyGramsSevenDayBucket() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            CreatineEntry(date: today.addingTimeInterval(3600), grams: 5),
            CreatineEntry(date: yesterday.addingTimeInterval(3600), grams: 5),
        ]
        let buckets = CreatineEngine.dailyGrams(entries: entries, days: 7, now: today.addingTimeInterval(7200), calendar: calendar)
        XCTAssertEqual(buckets.count, 7)
        XCTAssertEqual(buckets.last?.grams ?? 0, 5, accuracy: 0.01)
        XCTAssertEqual(buckets[buckets.count - 2].grams, 5, accuracy: 0.01)
    }

    func testCurrentStreakRequiresYesterdayWhenNotTakenToday() {
        let today = calendar.startOfDay(for: Self.fixedNow)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [CreatineEntry(date: yesterday.addingTimeInterval(1000), grams: 5)]
        let streak = CreatineEngine.currentStreak(entries: entries, hasTakenToday: false, now: today.addingTimeInterval(3600), calendar: calendar)
        XCTAssertEqual(streak, 1)
    }

    func testWeeklyCompliance() {
        let today = calendar.startOfDay(for: Self.fixedNow)
        var entries: [CreatineEntry] = []
        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            entries.append(CreatineEntry(date: day.addingTimeInterval(1000), grams: 5))
        }
        let c = CreatineEngine.weeklyCompliance(entries: entries, now: today.addingTimeInterval(5000), calendar: calendar)
        XCTAssertEqual(c.taken, 3)
        XCTAssertEqual(c.total, 7)
    }

    // MARK: - Streaks, doses, compliance

    private func entry(daysAgo: Int, hour: Double = 1000, grams: Double = 5) -> CreatineEntry {
        let today = calendar.startOfDay(for: Self.fixedNow)
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
        return CreatineEntry(date: day.addingTimeInterval(hour), grams: grams)
    }

    private var now: Date { calendar.startOfDay(for: Self.fixedNow).addingTimeInterval(5000) }

    func testCurrentStreakCountsConsecutiveDaysIncludingToday() {
        let entries = [entry(daysAgo: 0), entry(daysAgo: 1), entry(daysAgo: 2), entry(daysAgo: 4)]
        XCTAssertEqual(CreatineEngine.currentStreak(entries: entries, hasTakenToday: true, now: now, calendar: calendar), 3)
    }

    func testCurrentStreakZeroWhenYesterdayMissedAndNotTakenToday() {
        let entries = [entry(daysAgo: 2), entry(daysAgo: 3)]
        XCTAssertEqual(CreatineEngine.currentStreak(entries: entries, hasTakenToday: false, now: now, calendar: calendar), 0)
    }

    func testLongestStreak() {
        let entries = [entry(daysAgo: 0), entry(daysAgo: 1),
                       entry(daysAgo: 5), entry(daysAgo: 6), entry(daysAgo: 7), entry(daysAgo: 8)]
        XCTAssertEqual(CreatineEngine.longestStreak(entries: entries, calendar: calendar), 4)
        XCTAssertEqual(CreatineEngine.longestStreak(entries: [], calendar: calendar), 0)
        // Multiple entries on one day count once.
        XCTAssertEqual(CreatineEngine.longestStreak(entries: [entry(daysAgo: 0), entry(daysAgo: 0, hour: 2000)], calendar: calendar), 1)
    }

    func testDosesRemainingToday() {
        XCTAssertEqual(CreatineEngine.dosesRemainingToday(isLoadingPhase: true, loadingDosesPerDay: 4, todayEntryCount: 1, todayComplete: false), 3)
        XCTAssertEqual(CreatineEngine.dosesRemainingToday(isLoadingPhase: true, loadingDosesPerDay: 4, todayEntryCount: 6, todayComplete: true), 0)
        XCTAssertEqual(CreatineEngine.dosesRemainingToday(isLoadingPhase: false, loadingDosesPerDay: 4, todayEntryCount: 0, todayComplete: false), 1)
        XCTAssertEqual(CreatineEngine.dosesRemainingToday(isLoadingPhase: false, loadingDosesPerDay: 4, todayEntryCount: 1, todayComplete: true), 0)
    }

    func testTodayCompleteAndTotals() {
        XCTAssertTrue(CreatineEngine.todayComplete(todayTotalGrams: 5, dailyTargetGrams: 5))
        XCTAssertFalse(CreatineEngine.todayComplete(todayTotalGrams: 3, dailyTargetGrams: 5))
        XCTAssertEqual(CreatineEngine.todayTotalGrams(todayEntries: [entry(daysAgo: 0, grams: 2.5), entry(daysAgo: 0, grams: 2.5)]), 5, accuracy: 0.001)
    }

    func testWeeklyCompliancePercentageAndHistoryStats() {
        let entries = (0..<7).map { entry(daysAgo: $0) }
        let c = CreatineEngine.weeklyCompliance(entries: entries, now: now, calendar: calendar)
        XCTAssertEqual(c.percentage, 100, accuracy: 0.001)
        let none = CreatineEngine.weeklyCompliance(entries: [], now: now, calendar: calendar)
        XCTAssertEqual(none.percentage, 0, accuracy: 0.001)

        let daily = CreatineEngine.dailyGrams(entries: [entry(daysAgo: 0, grams: 5), entry(daysAgo: 2, grams: 3)], days: 7, now: now, calendar: calendar)
        let stats = CreatineEngine.historyStats(for: daily)
        XCTAssertEqual(stats.daysTracked, 2)
        XCTAssertEqual(stats.total, 8, accuracy: 0.001)
        XCTAssertEqual(stats.avgPerDay, 4, accuracy: 0.001)
    }
}
