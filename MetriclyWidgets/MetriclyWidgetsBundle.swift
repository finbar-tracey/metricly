import WidgetKit
import SwiftUI

@main
struct MetriclyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home screen
        StreakWidget()
        MetriclyWidget()
        MetriclyLargeWidget()
        TodaysPlanWidget()
        CaffeineWidget()
        WaterWidget()
        WeeklyRingsWidget()
        // Lock screen & StandBy
        MetriclyLockScreenWidget()
        MetriclyStreakCircularWidget()
        // Live Activity
        WorkoutLiveActivityWidget()
    }
}
