import XCTest
@testable import tracker

/// Round-trip + freshness tests for `TodayPlanStore` and `InsightsStore`.
final class StoreRoundTripTests: XCTestCase {

    private let suiteName = "group.com.Finbar.FinApp"

    override func setUp() {
        super.setUp()
        let d = UserDefaults(suiteName: suiteName)
        d?.removeObject(forKey: "currentTodayPlan")
        d?.removeObject(forKey: "currentInsights")
        d?.removeObject(forKey: "currentInsightsGeneratedAt")
    }

    override func tearDown() {
        let d = UserDefaults(suiteName: suiteName)
        d?.removeObject(forKey: "currentTodayPlan")
        d?.removeObject(forKey: "currentInsights")
        d?.removeObject(forKey: "currentInsightsGeneratedAt")
        super.tearDown()
    }

    // MARK: - TodayPlanStore

    func testTodayPlanRoundTrip() {
        let plan = TodayPlan(
            scheduledName: "Push Day",
            recommendedName: "Push Day",
            intensity: .moderate,
            reasons: ["Sleep was good", "HRV is up"],
            adjustments: ["Top set on bench"],
            confidence: .high,
            alreadyTrainedToday: false,
            goEasyOnGroups: [.shoulders],
            avoidGroups: [],
            generatedAt: .now
        )
        TodayPlanStore.save(plan)
        let loaded = TodayPlanStore.load()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.recommendedName, "Push Day")
        XCTAssertEqual(loaded?.intensity, .moderate)
        XCTAssertEqual(loaded?.confidence, .high)
        XCTAssertEqual(loaded?.reasons, ["Sleep was good", "HRV is up"])
        XCTAssertEqual(loaded?.adjustments, ["Top set on bench"])
        XCTAssertEqual(loaded?.goEasyOnGroups, [.shoulders])
    }

    func testTodayPlanLoadReturnsNilWhenNothingSaved() {
        XCTAssertNil(TodayPlanStore.load())
    }

    func testStaleTodayPlanIsRejected() {
        // Manually persist a plan generated yesterday — load() should reject it
        let stale = TodayPlan(
            scheduledName: nil,
            recommendedName: "Old Plan",
            intensity: .light,
            reasons: [],
            adjustments: [],
            confidence: .low,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: [],
            generatedAt: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .distantPast
        )
        guard let data = try? JSONEncoder().encode(stale) else { return XCTFail() }
        UserDefaults(suiteName: suiteName)?.set(data, forKey: "currentTodayPlan")

        XCTAssertNil(TodayPlanStore.load(), "Plans from previous days must not load")
    }

    func testTodayPlanIsLoadedWhenGeneratedToday() {
        let plan = TodayPlan(
            scheduledName: nil,
            recommendedName: "Today's Plan",
            intensity: .hard,
            reasons: [],
            adjustments: [],
            confidence: .medium,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: [],
            generatedAt: Calendar.current.startOfDay(for: .now)   // same calendar day
        )
        TodayPlanStore.save(plan)
        XCTAssertNotNil(TodayPlanStore.load())
    }

    // MARK: - InsightsStore

    func testInsightsRoundTrip() {
        let insights = [
            Insight(category: .sleep, title: "Sleep matters",
                    message: "Better lifts after 7+h",
                    detail: "30 sessions", strength: .strong,
                    icon: "moon.fill", weight: 50.0),
            Insight(category: .caffeine, title: "Late caffeine",
                    message: "Sleeps 30 min less",
                    detail: "20 days", strength: .moderate,
                    icon: "cup.and.saucer.fill", weight: 20.0),
        ]
        InsightsStore.save(insights)
        let loaded = InsightsStore.load()

        XCTAssertEqual(loaded?.count, 2)
        XCTAssertEqual(loaded?.first?.title, "Sleep matters")
        XCTAssertEqual(loaded?.first?.strength, .strong)
        XCTAssertEqual(loaded?.last?.category, .caffeine)
    }

    func testInsightsReturnsNilWhenEmpty() {
        XCTAssertNil(InsightsStore.load())
    }

    func testInsightsAreRejectedAfterSevenDays() {
        // Save normally, then rewind the timestamp to 8 days ago
        let insights = [
            Insight(category: .consistency, title: "Old",
                    message: "Test", detail: nil, strength: .weak,
                    icon: "calendar", weight: 1.0)
        ]
        InsightsStore.save(insights)
        let eightDaysAgo = Date.now.addingTimeInterval(-8 * 24 * 3600)
        UserDefaults(suiteName: suiteName)?.set(
            eightDaysAgo.timeIntervalSince1970,
            forKey: "currentInsightsGeneratedAt"
        )
        XCTAssertNil(InsightsStore.load(), "Insights older than 7 days must not load")
    }

    func testInsightsAreLoadedWithinSevenDays() {
        let insights = [
            Insight(category: .recovery, title: "Recent",
                    message: "Test", detail: nil, strength: .moderate,
                    icon: "bed.double.fill", weight: 5.0)
        ]
        InsightsStore.save(insights)
        // Default timestamp is "now" — should always load
        XCTAssertNotNil(InsightsStore.load())
    }

    func testInsightSavingPreservesIDs() {
        let original = Insight(
            category: .sleep, title: "X", message: "Y",
            detail: nil, strength: .strong, icon: "z", weight: 1.0
        )
        let id = original.id
        InsightsStore.save([original])
        XCTAssertEqual(InsightsStore.load()?.first?.id, id,
                       "UUIDs must survive encode/decode round-trip")
    }
}
