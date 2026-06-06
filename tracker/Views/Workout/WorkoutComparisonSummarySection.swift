import SwiftUI
import SwiftData

enum WorkoutComparisonSummarySection {

    static func pickerCard(
        workouts: [Workout],
        leftWorkout: Binding<Workout?>,
        rightWorkout: Binding<Workout?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Select Workouts", icon: "arrow.left.arrow.right", color: .accentColor)

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    pickerBadge(tag: "A", colors: [.blue, AppTheme.Signal.calm], shadow: .blue)
                    Picker("First", selection: leftWorkout) {
                        Text("Select workout…").tag(nil as Workout?)
                        ForEach(workouts) { w in Text(workoutLabel(w)).tag(w as Workout?) }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 13)

                Divider().padding(.leading, 66)

                HStack(spacing: 12) {
                    pickerBadge(tag: "B", colors: [.orange, AppTheme.Signal.actionOrange], shadow: .orange)
                    Picker("Second", selection: rightWorkout) {
                        Text("Select workout…").tag(nil as Workout?)
                        ForEach(workouts) { w in Text(workoutLabel(w)).tag(w as Workout?) }
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 13)
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
        }
        .appCard()
    }

    static func comparisonHeroCard(left: Workout, right: Workout, weightUnit: WeightUnit) -> some View {
        let leftVol = volume(left)
        let rightVol = volume(right)
        let volDiff = leftVol > 0 ? ((rightVol - leftVol) / leftVol) * 100 : 0
        let bIsAhead = rightVol > leftVol

        return HeroCard(palette: bIsAhead ? AppTheme.Gradients.caution : AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Volume Comparison")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Image(systemName: bIsAhead ? "arrow.up.right" : "arrow.down.right")
                                .font(.system(size: 22, weight: .bold))
                            Text(String(format: "%+.1f%%", volDiff))
                                .font(.system(size: 36, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                        }
                        .foregroundStyle(.white)
                    }
                    Spacer()
                }

                HStack(spacing: 0) {
                    heroSideCol(label: left.name, date: left.date, value: formatVolume(leftVol, weightUnit: weightUnit), tag: "A")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 48)
                    heroSideCol(label: right.name, date: right.date, value: formatVolume(rightVol, weightUnit: weightUnit), tag: "B")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }

    static func summaryCard(left: Workout, right: Workout, weightUnit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Summary", icon: "list.bullet.rectangle", color: .accentColor)
                Spacer()
                HStack(spacing: 8) {
                    comparisonTag("A", colors: [.blue, AppTheme.Signal.calm], shadow: .blue)
                    Text("vs")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    comparisonTag("B", colors: [.orange, AppTheme.Signal.actionOrange], shadow: .orange)
                }
            }

            VStack(spacing: 0) {
                summaryRow(label: "Exercises",
                           left: "\(left.exercises.count)", right: "\(right.exercises.count)",
                           leftNum: Double(left.exercises.count), rightNum: Double(right.exercises.count))
                Divider().padding(.leading, 16)
                summaryRow(label: "Total Sets",
                           left: "\(totalSets(left))", right: "\(totalSets(right))",
                           leftNum: Double(totalSets(left)), rightNum: Double(totalSets(right)))
                Divider().padding(.leading, 16)
                summaryRow(label: "Volume",
                           left: formatVolume(volume(left), weightUnit: weightUnit),
                           right: formatVolume(volume(right), weightUnit: weightUnit),
                           leftNum: volume(left), rightNum: volume(right))
                if let ld = left.formattedDuration, let rd = right.formattedDuration,
                   let ls = left.endTime.map({ $0.timeIntervalSince(left.date) }),
                   let rs = right.endTime.map({ $0.timeIntervalSince(right.date) }) {
                    Divider().padding(.leading, 16)
                    summaryRow(label: "Duration", left: ld, right: rd, leftNum: ls, rightNum: rs)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    static func emptyStateCard() -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("Pick Two Workouts").font(.headline)
                Text("Select a workout A and workout B above to compare them side by side.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    static func totalSets(_ workout: Workout) -> Int {
        workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
    }

    static func volume(_ workout: Workout) -> Double {
        workout.exercises.reduce(0.0) { total, ex in
            total + ex.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
        }
    }

    static func formatVolume(_ volumeKg: Double, weightUnit: WeightUnit) -> String {
        let displayValue = weightUnit.display(volumeKg)
        if displayValue >= 1000 { return String(format: "%.1fk %@", displayValue / 1000, weightUnit.label) }
        return String(format: "%.0f %@", displayValue, weightUnit.label)
    }

    private static func pickerBadge(tag: String, colors: [Color], shadow: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 38, height: 38)
                .shadow(color: shadow.opacity(0.40), radius: 5, y: 2)
            Text(tag)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private static func heroSideCol(label: String, date: Date, value: String, tag: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Text(tag)
                    .font(.system(size: 10, weight: .black))
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(.white.opacity(0.25), in: Capsule())
                    .foregroundStyle(.white)
                Text(label)
                    .font(.caption.weight(.semibold)).foregroundStyle(.white).lineLimit(1)
            }
            Text(date, format: .dateTime.month(.abbreviated).day().year())
                .font(.caption2).foregroundStyle(.white.opacity(0.65))
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private static func comparisonTag(_ label: String, colors: [Color], shadow: Color) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing), in: Capsule())
            .shadow(color: shadow.opacity(0.40), radius: 4, y: 2)
    }

    private static func summaryRow(label: String, left: String, right: String, leftNum: Double, rightNum: Double) -> some View {
        HStack(spacing: 8) {
            Text(left)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(leftNum >= rightNum ? Color.blue : Color.blue.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 2) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                if abs(leftNum - rightNum) > 0.001 {
                    Image(systemName: leftNum > rightNum ? "a.circle.fill" : "b.circle.fill")
                        .font(.system(size: 10)).foregroundStyle(leftNum > rightNum ? .blue : .orange)
                }
            }
            .frame(maxWidth: .infinity)

            Text(right)
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(rightNum >= leftNum ? Color.orange : Color.orange.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    private static func workoutLabel(_ workout: Workout) -> String {
        "\(workout.name) — \(workout.date.formatted(.dateTime.month(.abbreviated).day().year()))"
    }
}
