import SwiftUI

/// Muscle-readiness grid section for the home dashboard. Pure presentation
/// of the recovery engine's per-muscle freshness output.
///
/// Extracted from HomeDashboardView during the sprint-2 decomposition —
/// the parent was 1700+ LOC and Swift's type checker was at its limit.
struct HomeMuscleReadinessSection: View {
    let recovery: RecoveryResult

    /// Per-muscle freshness, sorted most-recovered first so the list
    /// reads as a ranking: train from the top, protect the bottom.
    private var ranked: [MuscleFatigueResult] {
        recovery.muscleResults.sorted { $0.freshness > $1.freshness }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Muscle Readiness", icon: "figure.strengthtraining.traditional", color: .purple)
                Spacer()
                NavigationLink { MuscleRecoveryView() } label: {
                    Text("Details")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.purple)
                }
            }

            if let summary = summary { summaryHeadline(summary) }

            VStack(spacing: 10) {
                ForEach(ranked, id: \.group) { result in
                    NavigationLink { MuscleRecoveryView() } label: {
                        readinessRow(result)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .appCard()
    }

    // MARK: - Ranked row

    private func readinessRow(_ result: MuscleFatigueResult) -> some View {
        let color = RecoveryEngine.freshnessColor(result.freshness)
        let label = RecoveryEngine.freshnessLabel(result.freshness)
        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.26), color.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(Circle().stroke(color.opacity(0.30), lineWidth: 0.5))
                MuscleIconView(group: result.group, color: color)
                    .frame(width: 19, height: 19)
            }
            Text(result.group.rawValue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .frame(width: 76, alignment: .leading)
            GradientProgressBar(value: result.freshness, color: color, height: 7)
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .frame(width: 82, alignment: .trailing)
        }
    }

    // MARK: - Summary headline

    /// (title, detail) takeaway above the list, or nil when there's no
    /// muscle data yet. Title uses the engine's recommended split when
    /// it's a real session ("Train Push today"); detail names the
    /// freshest groups and flags the most-fatigued one if it genuinely
    /// needs another day.
    private var summary: (title: String, detail: String)? {
        guard !ranked.isEmpty else { return nil }
        let freshest = ranked.prefix(2).map(\.group.rawValue)

        let type = recovery.suggestedWorkoutType
        let title: String
        if !type.isEmpty, !["rest", "anything"].contains(type.lowercased()) {
            title = "Train \(type) today"
        } else {
            title = "\(listPhrase(freshest)) freshest"
        }

        var detail = "\(listPhrase(freshest)) most recovered"
        if let worst = ranked.last,
           RecoveryEngine.freshnessLabel(worst.freshness) == "Fatigued"
            || RecoveryEngine.freshnessLabel(worst.freshness) == "Recovering" {
            detail += " · \(worst.group.rawValue) needs another day"
        }
        return (title, detail)
    }

    private func summaryHeadline(_ s: (title: String, detail: String)) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.purple)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(s.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.purple.opacity(0.18), lineWidth: 0.5)
        )
    }

    /// "Chest", "Chest & Back", lowercased for inline reading.
    private func listPhrase(_ names: [String]) -> String {
        switch names.count {
        case 0:  return ""
        case 1:  return names[0]
        default: return "\(names[0]) & \(names[1])"
        }
    }
}
