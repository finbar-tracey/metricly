import XCTest
@testable import tracker

final class PersonalInsightsEngineTests: XCTestCase {

    // MARK: - Empty / sparse inputs

    func testNoDataProducesNoInsights() {
        let result = PersonalInsightsEngine.generate(.init())
        XCTAssertTrue(result.isEmpty)
    }

    func testSparseDataStillReturnsTrainingFrequency() {
        // 4 sessions in 28 days is the minimum for a training-frequency insight
        let workouts = (0..<4).map { i in
            makeWorkout(daysAgo: i * 2)
        }
        let inputs = PersonalInsightsEngine.Inputs(workouts: workouts)
        let result = PersonalInsightsEngine.generate(inputs)
        XCTAssertTrue(result.contains { $0.category == .consistency })
    }

    // MARK: - Late caffeine × sleep

    func testLateCaffeineProducesInsightWhenPatternIsClear() {
        // 6 days with caffeine after 3pm and short sleep, 6 days with only morning caffeine + good sleep
        var caffeine: [CaffeineEntry] = []
        var sleep: [(date: Date, minutes: Double)] = []
        let cal = Calendar.current

        for i in 0..<6 {
            let day = cal.date(byAdding: .day, value: -i, to: .now)!
            let lateTime = cal.date(bySettingHour: 17, minute: 0, second: 0, of: day)!
            caffeine.append(CaffeineEntry(date: lateTime, milligrams: 100, source: "Coffee"))
            sleep.append((day, 6 * 60))    // 6h
        }
        for i in 7..<13 {
            let day = cal.date(byAdding: .day, value: -i, to: .now)!
            let earlyTime = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day)!
            caffeine.append(CaffeineEntry(date: earlyTime, milligrams: 100, source: "Coffee"))
            sleep.append((day, 8 * 60))    // 8h
        }

        let inputs = PersonalInsightsEngine.Inputs(caffeine: caffeine, sleepByDay: sleep)
        let insights = PersonalInsightsEngine.generate(inputs)
        XCTAssertTrue(insights.contains { $0.category == .caffeine })
    }

    func testNoCaffeineInsightWithTooFewDays() {
        // Only 2 days of each — under the 4-day minimum
        var caffeine: [CaffeineEntry] = []
        var sleep: [(date: Date, minutes: Double)] = []
        let cal = Calendar.current
        for i in 0..<2 {
            let day = cal.date(byAdding: .day, value: -i, to: .now)!
            caffeine.append(CaffeineEntry(date: cal.date(bySettingHour: 17, minute: 0, second: 0, of: day)!,
                                           milligrams: 100, source: "Coffee"))
            sleep.append((day, 6 * 60))
        }
        let inputs = PersonalInsightsEngine.Inputs(caffeine: caffeine, sleepByDay: sleep)
        let insights = PersonalInsightsEngine.generate(inputs)
        XCTAssertFalse(insights.contains { $0.category == .caffeine })
    }

    // MARK: - Sorting

    func testInsightsAreSortedByWeight() {
        // Build inputs that produce multiple insights and verify ordering
        let workouts = (0..<10).map { makeWorkout(daysAgo: $0) }
        let inputs = PersonalInsightsEngine.Inputs(workouts: workouts)
        let insights = PersonalInsightsEngine.generate(inputs)

        for i in 1..<insights.count {
            XCTAssertGreaterThanOrEqual(
                insights[i-1].weight, insights[i].weight,
                "Insights must be sorted by weight descending"
            )
        }
    }

    // MARK: - Training frequency trend

    func testFrequencyTrendUpDetectsIncrease() {
        // 10 sessions in last 28 days, 4 in the prior 28 — strong upward shift
        var workouts: [Workout] = []
        for i in 0..<10 {
            workouts.append(makeWorkout(daysAgo: i * 2))         // every 2 days, recent
        }
        for i in 0..<4 {
            workouts.append(makeWorkout(daysAgo: 30 + i * 7))    // sparse, prior month
        }
        let inputs = PersonalInsightsEngine.Inputs(workouts: workouts)
        let insights = PersonalInsightsEngine.generate(inputs)
        XCTAssertTrue(insights.contains { $0.category == .consistency && $0.title.contains("more") })
    }

    func testFrequencyTrendDownDetectsDecrease() {
        var workouts: [Workout] = []
        for i in 0..<4 {
            workouts.append(makeWorkout(daysAgo: i * 7))        // sparse recent
        }
        for i in 0..<10 {
            workouts.append(makeWorkout(daysAgo: 28 + i * 2))    // dense prior month
        }
        let inputs = PersonalInsightsEngine.Inputs(workouts: workouts)
        let insights = PersonalInsightsEngine.generate(inputs)
        XCTAssertTrue(insights.contains { $0.category == .consistency && $0.title.contains("less") })
    }

    func testFrequencyTrendIgnoredWhenNoBaseline() {
        // Only 3 sessions in the prior month — below the 4-session baseline
        var workouts: [Workout] = []
        for i in 0..<10 {
            workouts.append(makeWorkout(daysAgo: i * 2))
        }
        for i in 0..<3 {
            workouts.append(makeWorkout(daysAgo: 30 + i * 7))
        }
        let inputs = PersonalInsightsEngine.Inputs(workouts: workouts)
        let insights = PersonalInsightsEngine.generate(inputs)
        XCTAssertFalse(insights.contains { $0.title.contains("more lately") || $0.title.contains("less lately") })
    }

    // MARK: - Helpers

    private func makeWorkout(daysAgo: Int) -> Workout {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now)!
        let w = Workout(name: "Push", date: date)
        w.endTime = date.addingTimeInterval(3600)
        return w
    }
}
