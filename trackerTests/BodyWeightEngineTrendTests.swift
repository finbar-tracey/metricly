import XCTest
@testable import tracker

final class BodyWeightEngineTrendTests: XCTestCase {

    func testMovingAverageTrendSmooths() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let entries = (0..<5).map { i in
            BodyWeightEntry(date: base.addingTimeInterval(Double(i) * 86400), weight: 70 + Double(i) * 0.5)
        }
        let chart = BodyWeightEngine.chartEntries(from: entries.reversed(), maxCount: 90)
        let trend = BodyWeightEngine.movingAverageTrend(chartEntries: chart) { $0 }
        XCTAssertEqual(trend.count, chart.count)
        XCTAssertLessThanOrEqual(trend.last?.value ?? 0, 72.5)
    }

    func testChartYDomainPadding() {
        let domain = BodyWeightEngine.chartYDomain(displayWeights: [70, 72, 71])
        XCTAssertLessThan(domain.lowerBound, 70)
        XCTAssertGreaterThan(domain.upperBound, 72)
    }

    func testSummaryChange30d() {
        let now = Date()
        let cal = Calendar.current
        let old = cal.date(byAdding: .day, value: -35, to: now)!
        let mid = cal.date(byAdding: .day, value: -10, to: now)!
        let entries = [
            BodyWeightEntry(date: now, weight: 75),
            BodyWeightEntry(date: mid, weight: 74),
            BodyWeightEntry(date: old, weight: 70),
        ]
        let s = BodyWeightEngine.summary(entries: entries, now: now, calendar: cal)
        XCTAssertEqual(s.changeKg ?? 0, 5, accuracy: 0.01)
    }
}
