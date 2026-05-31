import XCTest
@testable import tracker

final class CreatineEngineChartBucketsTests: XCTestCase {

    private let calendar = Calendar.current

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
        let today = calendar.startOfDay(for: .now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [CreatineEntry(date: yesterday.addingTimeInterval(1000), grams: 5)]
        let streak = CreatineEngine.currentStreak(entries: entries, hasTakenToday: false, now: today.addingTimeInterval(3600), calendar: calendar)
        XCTAssertEqual(streak, 1)
    }

    func testWeeklyCompliance() {
        let today = calendar.startOfDay(for: .now)
        var entries: [CreatineEntry] = []
        for offset in 0..<3 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            entries.append(CreatineEntry(date: day.addingTimeInterval(1000), grams: 5))
        }
        let c = CreatineEngine.weeklyCompliance(entries: entries, now: today.addingTimeInterval(5000), calendar: calendar)
        XCTAssertEqual(c.taken, 3)
        XCTAssertEqual(c.total, 7)
    }
}
