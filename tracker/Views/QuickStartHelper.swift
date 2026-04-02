import SwiftUI
import SwiftData

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

/// A card shown on the main workout list when there's a scheduled workout for today.
struct QuickStartCard: View {
    let programName: String
    let workoutName: String
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today's Workout")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(workoutName)
                        .font(.headline)
                }
                Spacer()
                Text(programName)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemFill), in: .capsule)
            }

            Button(action: onStart) {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Start Workout")
                }
                .font(.subheadline.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(.tint, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
