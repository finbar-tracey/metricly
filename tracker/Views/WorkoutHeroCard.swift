import SwiftUI

/// Slim workout-hero strip at the top of WorkoutDetailView. Read-only
/// presentation — all values are computed by the parent and passed in.
///
/// Note: this hero deliberately doesn't use the shared `HeroCard`
/// component because it's been intentionally slimmed down (single
/// gradient, no sheen / circles, smaller corner radius). Pulling
/// those exceptions into `HeroCard` would broaden its API past
/// usefulness.
struct WorkoutHeroCard: View {
    let workout: Workout
    let weightUnit: WeightUnit
    /// "x/y" string for the Done stat — parent precomputes so we avoid
    /// re-counting in the view body.
    let progressFraction: String
    /// 0–1 ratio for the under-stats progress bar.
    let progressRatio: Double
    let totalWorkingSets: Int
    let elapsedTime: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: workout.isFinished
                    ? AppTheme.Gradients.recovery
                    : AppTheme.Gradients.calm,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(alignment: .leading, spacing: 10) {
                // Top row: status + relative date + rating (if finished)
                HStack(spacing: 8) {
                    Label(
                        workout.isFinished ? "Completed" : "In Progress",
                        systemImage: workout.isFinished ? "checkmark.circle.fill" : "timer"
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9).padding(.vertical, 3)
                    .background(.white.opacity(0.18), in: Capsule())

                    Text(workout.date, format: .dateTime.month(.abbreviated).day())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.80))

                    Spacer()

                    if workout.isFinished, let rating = workout.rating, rating > 0 {
                        HStack(spacing: 2) {
                            ForEach(1...5, id: \.self) { i in
                                Image(systemName: i <= rating ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(i <= rating ? .yellow : .white.opacity(0.30))
                            }
                        }
                    }
                }

                // Stats strip — 4 stats, no panel-within-panel
                HStack(spacing: 0) {
                    HeroStatCol(value: progressFraction,
                                label: "Done",
                                icon: "figure.strengthtraining.functional")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: "\(totalWorkingSets)",
                                label: "Sets",
                                icon: "repeat")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: workout.isFinished ? (workout.formattedDuration ?? "–") : elapsedTime,
                                label: "Duration",
                                icon: "clock")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 28)
                    HeroStatCol(value: weightUnit.formatShort(workout.totalVolumeKg()),
                                label: "Volume",
                                icon: "scalemass")
                }

                // Progress bar — fills as exercises log their first working set
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.20))
                        Capsule()
                            .fill(.white.opacity(0.90))
                            .frame(width: max(2, geo.size.width * progressRatio))
                    }
                }
                .frame(height: 3)
                .accessibilityLabel("Progress: \(progressFraction)")
            }
            .padding(14)
        }
        .frame(minHeight: 140)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(workout.isFinished
            ? "Workout completed, duration \(workout.formattedDuration ?? "")"
            : "Workout in progress, elapsed \(elapsedTime)")
    }
}
