import SwiftUI
import SwiftData
import UIKit

struct FinishWorkoutSessionPR: Identifiable {
    let id = UUID()
    let exerciseName: String
    let weight: Double
}

enum FinishWorkoutSummarySection {
    static func sessionPRs(workout: Workout, allExercises: [Exercise]) -> [FinishWorkoutSessionPR] {
        var prs: [FinishWorkoutSessionPR] = []
        for exercise in workout.exercises {
            let sessionBest = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
            guard sessionBest > 0 else { continue }
            let historicalBest = allExercises
                .filter { other in
                    other.name.lowercased() == exercise.name.lowercased()
                    && other.persistentModelID != exercise.persistentModelID
                    && !(other.workout?.isTemplate ?? true)
                }
                .flatMap(\.sets)
                .filter { !$0.isWarmUp }
                .map(\.weight)
                .max() ?? 0
            if sessionBest > historicalBest {
                prs.append(FinishWorkoutSessionPR(exerciseName: exercise.name, weight: sessionBest))
            }
        }
        return prs
    }

    static func celebrationCard(workout: Workout, rating: Binding<Int>, ratingLabel: String) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(colors: AppTheme.Gradients.recovery, startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 170, y: -60)
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 56, height: 56)
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 26, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(String(localized: "Great work!", comment: "Celebration headline on the finish-workout hero card"))
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)
                        Text(workout.name).font(.subheadline).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(String(localized: "How was it?", comment: "Prompt above the star rating row on the hero card"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    HStack(spacing: 12) {
                        ForEach(1...5, id: \.self) { value in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    rating.wrappedValue = value
                                }
                            } label: {
                                Image(systemName: value <= rating.wrappedValue ? "star.fill" : "star")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(value <= rating.wrappedValue ? .yellow : .white.opacity(0.50))
                                    .scaleEffect(value <= rating.wrappedValue ? 1.18 : 1.0)
                                    .shadow(color: value <= rating.wrappedValue ? Color.yellow.opacity(0.55) : .clear, radius: 6, y: 1)
                            }
                            .buttonStyle(.pressableCard)
                            .accessibilityLabel("\(value) star\(value == 1 ? "" : "s")")
                            .accessibilityAddTraits(value <= rating.wrappedValue ? .isSelected : [])
                        }
                        if rating.wrappedValue > 0 {
                            Text(ratingLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.85))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(20)
        }
        .heroCard()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workout complete. \(workout.name). Rate your session.")
    }

    static func statsCard(workout: Workout, totalSets: Int, totalVolume: Double, weightUnit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Summary", comment: "Section header above the duration / exercises / sets / volume stat strip"),
                icon: "chart.bar.fill", color: .accentColor
            )
            HStack(spacing: 0) {
                finishStat(icon: "clock", value: workout.formattedDuration ?? "-",
                           label: String(localized: "Duration", comment: "Stat label under workout duration"), color: .orange)
                Divider().frame(height: 50)
                finishStat(icon: "figure.strengthtraining.functional", value: "\(workout.exercises.count)",
                           label: String(localized: "Exercises", comment: "Stat label under the exercise count"), color: .accentColor)
                Divider().frame(height: 50)
                finishStat(icon: "repeat", value: "\(totalSets)",
                           label: String(localized: "Sets", comment: "Stat label under the working-set count"), color: .purple)
                Divider().frame(height: 50)
                finishStat(icon: "scalemass", value: formatVolume(totalVolume, weightUnit: weightUnit),
                           label: String(localized: "Volume", comment: "Stat label under the total weight lifted"), color: .green)
            }
            .padding(.vertical, 12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.07), radius: 12, x: 0, y: 3)
        }
    }

    static func prCard(sessionPRs: [FinishWorkoutSessionPR], weightUnit: WeightUnit) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: String(localized: "Personal Records", comment: "Section header above the PRs achieved in this session"),
                icon: "trophy.fill", color: .yellow
            )
            VStack(spacing: 0) {
                ForEach(sessionPRs) { pr in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.yellow.opacity(0.15)).frame(width: 36, height: 36)
                            Image(systemName: "trophy.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.yellow)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pr.exerciseName).font(.subheadline.weight(.semibold))
                            Text(String(
                                localized: "New best: \(weightUnit.format(pr.weight))",
                                comment: "Subtitle on a PR row; placeholder is the weight string e.g. '120 kg'"
                            ))
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    if pr.id != sessionPRs.last?.id {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
        }
    }

    private static func finishStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).font(.caption2.weight(.medium)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private static func formatVolume(_ volumeKg: Double, weightUnit: WeightUnit) -> String {
        let value = weightUnit.display(volumeKg)
        if value >= 1000 { return String(format: "%.1fk", value / 1000) }
        return String(format: "%.0f", value)
    }
}
