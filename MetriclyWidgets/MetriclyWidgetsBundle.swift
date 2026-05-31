import WidgetKit
import SwiftUI

@main
struct MetriclyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home screen
        ReadinessWidget()
        StreakWidget()
        MetriclyWidget()
        MetriclyLargeWidget()
        TodaysPlanWidget()
        CaffeineWidget()
        WaterWidget()
        WeeklyRingsWidget()
        // Lock screen & StandBy
        ReadinessCircularWidget()
        MetriclyLockScreenWidget()
        MetriclyStreakCircularWidget()
        // Live Activity
        WorkoutLiveActivityWidget()
    }
}
