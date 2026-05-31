import XCTest
@testable import tracker

final class CaffeineEngineChartBucketsTests: XCTestCase {

    private let calendar = Calendar.current

    func testDailyTotalsSevenDayBucket() {
        let today = calendar.startOfDay(for: Date(timeIntervalSince1970: 1_700_000_000))
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let entries = [
            CaffeineEntry(date: today.addingTimeInterval(3600), milligrams: 100, source: "Coffee"),
            CaffeineEntry(date: yesterday.addingTimeInterval(3600), milligrams: 50, source: "Tea"),
        ]
        let totals = CaffeineEngine.dailyTotals(entries: entries, days: 7, now: today.addingTimeInterval(7200), calendar: calendar)
        XCTAssertEqual(totals.count, 7)
        XCTAssertEqual(totals.last?.mg ?? 0, 100, accuracy: 0.01)
        let prior = totals[totals.count - 2]
        XCTAssertEqual(prior.mg, 50, accuracy: 0.01)
    }

    func testHistoryStatsFromBuckets() {
        let today = calendar.startOfDay(for: .now)
        let entries = [
            CaffeineEntry(date: today.addingTimeInterval(1000), milligrams: 80, source: "Coffee"),
            CaffeineEntry(date: today.addingTimeInterval(2000), milligrams: 40, source: "Coffee"),
        ]
        let totals = CaffeineEngine.dailyTotals(entries: entries, days: 7)
        let stats = CaffeineEngine.historyStats(for: totals)
        XCTAssertEqual(stats.daysTracked, 1)
        XCTAssertEqual(stats.total, 120, accuracy: 0.01)
        XCTAssertEqual(stats.avgPerDay, 120, accuracy: 0.01)
    }

    func testFrequentSourcesOrdersByCount() {
        let now = Date()
        let entries = (0..<5).map { i in
            CaffeineEntry(date: now.addingTimeInterval(Double(-i) * 3600), milligrams: 95, source: "Coffee")
        } + [
            CaffeineEntry(date: now.addingTimeInterval(-10_000), milligrams: 60, source: "Tea"),
        ]
        let frequent = CaffeineEngine.frequentSources(entries: entries)
        XCTAssertEqual(frequent.first?.name, "Coffee")
        XCTAssertEqual(frequent.first?.count, 5)
    }
}
