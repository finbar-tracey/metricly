import Foundation

/// Provides "today's workout" information from Training Programs.
/// Can be used by a Widget Extension once the target is created in Xcode.
struct QuickStartHelper {
    static func todaysWorkout(from programs: [TrainingProgram]) -> (programName: String, workoutName: String)? {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: .now) // 1=Sun, 7=Sat

        for program in programs where program.isActive {
            if let day = program.days.first(where: { $0.dayOfWeek == todayWeekday }) {
                return (program.name, day.workoutName)
            }
        }
        return nil
    }
}
