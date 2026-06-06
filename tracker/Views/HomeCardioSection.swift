import SwiftUI

/// Cardio summary card on the home dashboard: this week's km + last
/// session highlight. Read-only — deep-links into CardioHub or the
/// session detail.
struct HomeCardioSection: View {
    let sessions: [CardioSession]
    let weightUnit: WeightUnit

    var body: some View {
        let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: .now)?.start ?? .distantPast
        let thisWeekSessions = sessions.filter { $0.date >= weekStart }
        let thisWeekKm = thisWeekSessions.reduce(0) { $0 + $1.distanceMeters } / 1000
        let lastSession = sessions.first
        let distUnit = weightUnit.distanceUnit
        let useKm = distUnit == .km

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Cardio", icon: "figure.run", color: .orange)
                Spacer()
                NavigationLink { CardioHubView() } label: {
                    Text("See All").font(.caption.weight(.semibold)).foregroundStyle(.orange)
                }
            }

            HStack(spacing: 12) {
                // This week stat
                VStack(alignment: .leading, spacing: 6) {
                    Text("This Week")
                        // Caption2 (~11pt) preserves the all-caps small-label
                        // feel while letting Dynamic Type scale it.
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(.orange)
                        .tracking(0.4)
                        .textCase(.uppercase)
                    Text(String(format: "%.1f %@", distUnit.display(thisWeekKm), distUnit.label))
                        .font(.system(size: 24, weight: .black, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.orange)
                    Text("\(thisWeekSessions.count) session\(thisWeekSessions.count == 1 ? "" : "s")")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(
                    LinearGradient(
                        colors: [Color.orange.opacity(0.18), Color.orange.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(Color.orange.opacity(0.20), lineWidth: 0.5)
                )

                // Last run stat
                if let last = lastSession {
                    NavigationLink(destination: CardioSessionDetailView(session: last)) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Last Run")
                                .font(.system(.caption2, design: .rounded).weight(.bold))
                                .foregroundStyle(last.type.color)
                                .tracking(0.4)
                                .textCase(.uppercase)
                            Text(last.formattedDistance(useKm: useKm))
                                .font(.system(size: 24, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(last.type.color)
                            Text(last.formattedPace(useKm: useKm))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [last.type.color.opacity(0.18), last.type.color.opacity(0.06)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                                .stroke(last.type.color.opacity(0.20), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .appCard()
    }
}
