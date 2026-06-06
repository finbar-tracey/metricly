import SwiftUI

struct ReportShareCardView: View {
    let periodLabel: String
    let selectedPeriod: ReportPeriod
    let vibeEmoji: String
    let workoutCount: Int
    let totalSets: Int
    let totalVolume: Double
    let formattedDuration: String
    let volumeChange: Double?
    let prsHitCount: Int
    let prExerciseNames: [String]
    let muscleGroupSetCounts: [(group: MuscleGroup, sets: Int)]
    let bodyWeightStart: Double?
    let bodyWeightEnd: Double?
    let bodyWeightChange: Double?
    let avgSteps: Double?
    let avgSleepMinutes: Double?
    let avgRestingHR: Double?
    let avgHRV: Double?
    let currentStreak: Int
    let cardioCount: Int
    let cardioDistanceText: String
    let weightUnit: WeightUnit

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(vibeEmoji).font(.system(size: 36))
                Text(selectedPeriod == .week ? "Weekly Report" : "Monthly Report")
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(periodLabel)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
            }
            .padding(20).frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: AppTheme.Gradients.calm, startPoint: .topLeading, endPoint: .bottomTrailing)
            )

            HStack(spacing: 0) {
                shareStatItem(value: "\(workoutCount)", label: "Workouts")
                Divider().frame(height: 36)
                shareStatItem(value: "\(totalSets)", label: "Sets")
                Divider().frame(height: 36)
                shareStatItem(value: WeeklyMonthlyReportSections.formatVolume(totalVolume, weightUnit: weightUnit), label: "Volume")
                Divider().frame(height: 36)
                shareStatItem(value: formattedDuration, label: "Duration")
            }
            .padding(.vertical, 12)

            Divider()

            if cardioCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "figure.run").foregroundStyle(AppTheme.Signal.runOrange)
                    Text("\(cardioCount) cardio session\(cardioCount == 1 ? "" : "s")").font(.subheadline.bold())
                    Text(cardioDistanceText).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if prsHitCount > 0 {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundStyle(.yellow)
                    Text("\(prsHitCount) PR\(prsHitCount == 1 ? "" : "s")").font(.subheadline.bold())
                    Text(prExerciseNames.prefix(3).joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if !muscleGroupSetCounts.isEmpty {
                HStack(spacing: 6) {
                    ForEach(muscleGroupSetCounts.prefix(5), id: \.group) { item in
                        Text(item.group.rawValue).font(.caption2)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.1), in: Capsule())
                    }
                    if muscleGroupSetCounts.count > 5 {
                        Text("+\(muscleGroupSetCounts.count - 5)").font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if let startW = bodyWeightStart, let endW = bodyWeightEnd, bodyWeightChange != nil {
                HStack(spacing: 12) {
                    Label(weightUnit.formatShort(startW), systemImage: "scalemass")
                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                    Text(weightUnit.formatShort(endW))
                    if let change = bodyWeightChange {
                        Text("(\(change > 0 ? "+" : "")\(weightUnit.formatShort(abs(change))))")
                            .foregroundStyle(change > 0 ? .red : .green)
                    }
                    Spacer()
                }
                .font(.caption).padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            if avgSteps != nil || avgSleepMinutes != nil || avgRestingHR != nil || avgHRV != nil {
                HStack(spacing: 16) {
                    if let steps = avgSteps { Label(HealthFormatters.formatSteps(steps), systemImage: "figure.walk") }
                    if let sleep = avgSleepMinutes { Label(HealthFormatters.formatSleepShort(sleep), systemImage: "bed.double.fill") }
                    if let hr = avgRestingHR { Label("\(Int(hr))bpm", systemImage: "heart.fill") }
                    if let hrv = avgHRV { Label("\(Int(hrv))ms", systemImage: "waveform.path.ecg") }
                    Spacer()
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 20).padding(.vertical, 10)
                Divider()
            }

            HStack {
                Image(systemName: "dumbbell.fill").font(.caption)
                Text("Metricly").font(.caption.bold())
                Spacer()
                if currentStreak > 0 {
                    Text("\(currentStreak) day streak").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20).padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius).stroke(Color(.separator), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    }

    private func shareStatItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
