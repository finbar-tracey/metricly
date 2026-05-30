import XCTest
@testable import tracker

/// Round-trip + freshness tests for `TodayPlanStore` and `InsightsStore`.
final class StoreRoundTripTests: XCTestCase {

    private let suiteName = WidgetAppGroup.suiteName

    override func setUp() {
        super.setUp()
        let d = UserDefaults(suiteName: suiteName)
        d?.removeObject(forKey: "currentTodayPlan")
        d?.removeObject(forKey: "todayPlanHistory")
        d?.removeObject(forKey: "currentInsights")
        d?.removeObject(forKey: "currentInsightsGeneratedAt")
    }

    override func tearDown() {
        let d = UserDefaults(suiteName: suiteName)
        d?.removeObject(forKey: "currentTodayPlan")
        d?.removeObject(forKey: "todayPlanHistory")
        d?.removeObject(forKey: "currentInsights")
        d?.removeObject(forKey: "currentInsightsGeneratedAt")
        super.tearDown()
    }

    // MARK: - History helpers

    private func samplePlan(
        generatedAt: Date,
        name: String = "Plan",
        intensity: TodayPlan.Intensity = .moderate
    ) -> TodayPlan {
        TodayPlan(
            scheduledName: name,
            recommendedName: name,
            intensity: intensity,
            reasons: [],
            adjustments: [],
            confidence: .medium,
            alreadyTrainedToday: false,
            goEasyOnGroups: [],
            avoidGroups: [],
            generatedAt: generatedAt
        )
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: .now) ?? .now
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

    // MARK: - TodayPlanStore rolling history
    //
    // The history slot is what `ComplianceBackfill.run` queries to figure
    // out "what did the engine suggest on day N?". A bug here silently
    // collapses the trust-cal signal to nil — these tests pin the
    // ordering, dedup, prune, and lookup contract.

    func testHistoryIsEmptyByDefault() {
        XCTAssertTrue(TodayPlanStore.history().isEmpty,
                      "Empty store should return an empty array, not crash")
    }

    func testHistoryReturnsNewestFirst() {
        TodayPlanStore.save(samplePlan(generatedAt: day(-3), name: "Three"))
        TodayPlanStore.save(samplePlan(generatedAt: day(-1), name: "One"))
        TodayPlanStore.save(samplePlan(generatedAt: day(-2), name: "Two"))

        let h = TodayPlanStore.history()
        XCTAssertEqual(h.count, 3)
        XCTAssertEqual(h[0].recommendedName, "One")
        XCTAssertEqual(h[1].recommendedName, "Two")
        XCTAssertEqual(h[2].recommendedName, "Three")
    }

    func testSavingSameDayTwiceCollapsesToOneEntry() {
        // The user opened the app twice on the same day — the second
        // recompute should replace the first, not stack alongside it.
        //
        // Anchor on startOfDay(yesterday) + N hours rather than
        // day(-1) + N hours; the latter offsets from .now, so when
        // the test runs late in the day "yesterday + 18h" crosses
        // midnight into today and the dedup correctly DOESN'T fire.
        // The test was flaky on morning runs for the same reason.
        let yesterdayStart = Calendar.current.startOfDay(for: day(-1))
        let yesterdayMorning = yesterdayStart.addingTimeInterval(8 * 3600)
        let yesterdayEvening = yesterdayStart.addingTimeInterval(20 * 3600)
        TodayPlanStore.save(samplePlan(generatedAt: yesterdayMorning, name: "Morning"))
        TodayPlanStore.save(samplePlan(generatedAt: yesterdayEvening, name: "Evening"))
        let h = TodayPlanStore.history()
        XCTAssertEqual(h.count, 1, "Same calendar day must dedup")
        XCTAssertEqual(h.first?.recommendedName, "Evening",
                       "Latest write should win")
    }

    func testHistoryPrunesAtFourteenDayCutoff() {
        // Anything older than `historyLimit` days at save-time should be
        // dropped from the persisted blob — otherwise the cache grows
        // forever on a daily-active user.
        TodayPlanStore.save(samplePlan(generatedAt: day(-20), name: "Stale"))
        TodayPlanStore.save(samplePlan(generatedAt: day(-2),  name: "Fresh"))
        let h = TodayPlanStore.history()
        XCTAssertEqual(h.count, 1)
        XCTAssertEqual(h.first?.recommendedName, "Fresh",
                       "20-day-old plan must have been pruned at save")
    }

    func testPlanOnDayReturnsMatchingEntry() {
        let yesterdayPlan = samplePlan(generatedAt: day(-1), name: "Yesterday",
                                       intensity: .light)
        let twoDaysAgo    = samplePlan(generatedAt: day(-2), name: "Two Ago",
                                       intensity: .hard)
        TodayPlanStore.save(yesterdayPlan)
        TodayPlanStore.save(twoDaysAgo)

        let lookup = TodayPlanStore.plan(on: day(-1))
        XCTAssertEqual(lookup?.recommendedName, "Yesterday")
        XCTAssertEqual(lookup?.intensity, .light)
    }

    func testPlanOnDayReturnsNilForUnseenDay() {
        TodayPlanStore.save(samplePlan(generatedAt: day(-1), name: "One"))
        XCTAssertNil(TodayPlanStore.plan(on: day(-5)),
                     "A day the user didn't open the app should return nil")
    }

    func testHistoryReturnsEmptyOnCorruptBlob() {
        // Defensive: a malformed `todayPlanHistory` blob shouldn't crash
        // the engine — it should look like "no history yet". This is the
        // same shape failure mode as a JSON schema rename across builds.
        UserDefaults(suiteName: suiteName)?.set(
            Data([0x00, 0x01, 0x02]),
            forKey: "todayPlanHistory"
        )
        XCTAssertEqual(TodayPlanStore.history(), [])
    }

    func testHistoryLimitMatchesComplianceLookback() {
        // Cross-component invariant: the history window must be at least
        // as large as the compliance backfill's lookback, otherwise the
        // backfill asks for plans the store already discarded and every
        // event past the edge gets `suggested = nil`. This same assertion
        // lives in ComplianceBackfillTests — duplicated here so a
        // regression in either file is caught regardless of which test
        // bundle is run.
        XCTAssertGreaterThanOrEqual(
            TodayPlanStore.historyLimit,
            ComplianceBackfill.lookbackDays
        )
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
