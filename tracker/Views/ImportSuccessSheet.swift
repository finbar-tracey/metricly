import SwiftUI

/// "Wow moment" sheet shown after a Strong/Hevy import completes.
/// Replaces the bland "Imported 184 workouts" alert with the
/// reviewer's pitched shape — counts + concrete observations the
/// engine pulled out of the user's real history + a starting
/// recommendation with a one-tap CTA.
///
/// Inputs are pre-computed by `ImportAnalyzer.analyze(_:)`. The view
/// owns no analysis logic; if you want to surface a different
/// observation, add it to `ImportAnalysis` and reflect it here.
struct ImportSuccessSheet: View {
    let analysis: ImportAnalysis
    let onStartRecommended: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    celebration
                    headlineStats
                    observations
                    if analysis.recommendation != nil {
                        recommendationCard
                    }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Import complete",
                                    comment: "Navigation title on the post-import wow-moment sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done",
                                  comment: "Dismiss button on the post-import wow-moment sheet"),
                           action: onDismiss)
                        .font(.headline)
                }
            }
        }
    }

    // MARK: - Celebration

    private var celebration: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: AppTheme.Gradients.recovery,
                                          startPoint: .topLeading,
                                          endPoint: .bottomTrailing))
                    .frame(width: 84, height: 84)
                    .shadow(color: AppTheme.Signal.recovery.opacity(0.35),
                            radius: 16, y: 6)
                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 4) {
                Text(String(localized: "Your history is in",
                            comment: "Headline above the import wow-moment stats"))
                    .font(.title2.weight(.bold))
                if analysis.monthSpan >= 1 {
                    Text(String(
                        localized: "Spanning about \(analysis.monthSpan) months of training.",
                        comment: "Subtitle showing the imported history's month span"
                    ))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Headline stats

    private var headlineStats: some View {
        // Recovery-gradient hero card (not a flat appCard): the import is
        // a celebratory moment, so the counts get the same premium hero
        // treatment as the readiness surfaces — big white numbers on the
        // green→teal gradient, hairline dividers between.
        HeroCard(palette: AppTheme.Gradients.recovery) {
            HStack(spacing: 0) {
                statCol(label: String(localized: "Workouts",
                                      comment: "Headline-stat label for the workout count"),
                        value: "\(analysis.workoutCount)")
                heroDivider
                statCol(label: String(localized: "Exercises",
                                      comment: "Headline-stat label for the unique exercise count"),
                        value: "\(analysis.exerciseCount)")
                heroDivider
                statCol(label: String(localized: "Sets",
                                      comment: "Headline-stat label for the total set count"),
                        value: "\(analysis.totalSetCount)")
                if analysis.prCount > 0 {
                    heroDivider
                    statCol(label: String(localized: "Active PRs",
                                          comment: "Headline-stat label for the count of recently-set personal records"),
                            value: "\(analysis.prCount)")
                }
            }
            .padding(.vertical, 24)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
        }
    }

    /// Hairline separator between hero stat columns. A system `Divider`
    /// is invisible against the recovery gradient, so draw an explicit
    /// white-opacity rule instead.
    private var heroDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.25))
            .frame(width: 1, height: 40)
    }

    private func statCol(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 30, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Observations

    private var observations: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "Metricly noticed",
                        comment: "Section header above the observations the analyser pulled out of the imported history"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(spacing: 0) {
                ForEach(Array(observationLines.enumerated()), id: \.offset) { i, line in
                    observationRow(icon: line.icon, color: line.color, text: line.text)
                    if i < observationLines.count - 1 {
                        Divider().padding(.leading, 44)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
        }
        .padding(16)
        .appCard()
    }

    private func observationRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(color.opacity(0.18)).frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    /// Build the list of observations from the analysis. Empty array
    /// when the import was too sparse to say anything (no top
    /// exercise, no clear group balance) — caller renders the
    /// section anyway because the headline stats already make the
    /// import feel substantive.
    private var observationLines: [(icon: String, color: Color, text: String)] {
        var lines: [(String, Color, String)] = []

        if let top = analysis.topExercise {
            lines.append((
                "dumbbell.fill",
                .orange,
                String(localized: "\(top.name) is your most-frequent lift (\(top.hits) sessions).",
                       comment: "Observation about the user's most-frequent exercise; placeholders are the exercise name and the session count")
            ))
        }

        if let most = analysis.mostTrainedGroup {
            lines.append((
                "flame.fill",
                AppTheme.Signal.recovery,
                String(localized: "\(most.rawValue) is your highest-volume muscle group.",
                       comment: "Observation about the user's most-trained muscle group; placeholder is the group name (Chest/Back/etc.)")
            ))
        }

        if let least = analysis.leastTrainedGroup,
           least != analysis.mostTrainedGroup {
            lines.append((
                "moon.fill",
                .indigo,
                String(localized: "\(least.rawValue) is trained least often — Metricly will surface it as you go.",
                       comment: "Observation about the user's least-trained muscle group; placeholder is the group name")
            ))
        }

        if analysis.prCount > 0 {
            lines.append((
                "trophy.fill",
                .yellow,
                String(localized: "\(analysis.prCount) exercise(s) are still trending up — recent best lifts.",
                       comment: "Observation about how many exercises have recent estimated-1RM peaks")
            ))
        }

        return lines
    }

    // MARK: - Recommendation

    @ViewBuilder
    private var recommendationCard: some View {
        if let rec = analysis.recommendation {
            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.indigo)
                    Text(String(localized: "Recommended starting point",
                                comment: "Header above the suggested workout on the post-import wow-moment sheet"))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 6) {
                    Text(rec.workoutName)
                        .font(.title3.weight(.bold))
                    Text(String(localized: "Based on what you trained most often. Adaptive plan will refine this as Metricly gets to know you.",
                                comment: "Subtitle under the recommended starting workout, explaining how the engine refines the suggestion over time"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onStartRecommended) {
                    Label(String(localized: "Start Today's Workout",
                                 comment: "Primary CTA on the post-import wow-moment sheet — opens the adaptive workout"),
                          systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                }
                .buttonStyle(.pressableCard)
            }
            .padding(16)
            .appCard()
        }
    }
}
