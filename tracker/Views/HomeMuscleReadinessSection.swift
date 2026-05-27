import SwiftUI

/// Muscle-readiness grid section for the home dashboard. Pure presentation
/// of the recovery engine's per-muscle freshness output.
///
/// Extracted from HomeDashboardView during the sprint-2 decomposition —
/// the parent was 1700+ LOC and Swift's type checker was at its limit.
struct HomeMuscleReadinessSection: View {
    let recovery: RecoveryResult

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

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6),
                spacing: 14
            ) {
                ForEach(recovery.muscleResults, id: \.group) { result in
                    let color = RecoveryEngine.freshnessColor(result.freshness)
                    VStack(spacing: 7) {
                        ZStack {
                            Circle()
                                .fill(color.opacity(0.14))
                                .frame(width: 52, height: 52)
                            Circle()
                                .stroke(color.opacity(0.18), lineWidth: 4)
                                .frame(width: 52, height: 52)
                            Circle()
                                .trim(from: 0, to: result.freshness)
                                .stroke(
                                    color.gradient,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 52, height: 52)
                                .animation(.easeOut(duration: 0.7), value: result.freshness)
                                .shadow(color: color.opacity(0.4), radius: 4, y: 1)
                            MuscleIconView(group: result.group, color: color)
                                .frame(width: 22, height: 22)
                        }
                        Text(result.group.rawValue)
                            // Caption2 = 11pt default; .rounded preserved.
                            // Scales with Dynamic Type up to the minimum
                            // scale factor below.
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(color)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            HStack(spacing: 16) {
                legendDot(color: .green, label: "Ready")
                legendDot(color: .yellow, label: "Almost")
                legendDot(color: .orange, label: "Recovering")
                legendDot(color: .red, label: "Fatigued")
                Spacer()
            }
        }
        .appCard()
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
