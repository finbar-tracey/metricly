import SwiftUI

enum CardioBestsPRSection {

    static func allTimeSection(
        group: CardioBestsView.ActivityGroup,
        longestSession: CardioSession?,
        fastestPaceSession: CardioSession?,
        fastestSplit: (paceSecPerUnit: Double, session: CardioSession)?,
        longestDuration: CardioSession?,
        mostElevation: CardioSession?,
        mostCaloriesSession: CardioSession?,
        bestAerobicSession: CardioSession?,
        useKm: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "All-Time Records", icon: "trophy.fill", color: .yellow)

            VStack(spacing: 0) {
                if let s = longestSession {
                    recordRow(icon: "ruler", color: group.color,
                              label: "Longest Distance", value: s.formattedDistance(useKm: useKm),
                              sub: s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = fastestPaceSession {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "speedometer", color: .purple,
                              label: "Fastest Avg Pace", value: s.formattedPace(useKm: useKm),
                              sub: s.formattedDistance(useKm: useKm) + " · " +
                                   s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let split = fastestSplit {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "bolt.fill", color: .yellow,
                              label: "Fastest \(useKm ? "km" : "mi") Split",
                              value: formatPaceShort(split.paceSecPerUnit, useKm: useKm) + " /\(useKm ? "km" : "mi")",
                              sub: split.session.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: split.session)
                }
                if let s = longestDuration {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "clock.fill", color: .indigo,
                              label: "Longest Duration", value: s.formattedDuration,
                              sub: s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = mostElevation {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "mountain.2.fill", color: .brown,
                              label: "Most Elevation", value: String(format: "%.0f m", s.elevationGainMeters),
                              sub: s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = mostCaloriesSession, let cal = s.caloriesBurned {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "flame.fill", color: .red,
                              label: "Most Calories", value: String(format: "%.0f kcal", cal),
                              sub: s.formattedDistance(useKm: useKm) + " · " +
                                   s.date.formatted(.dateTime.day().month(.abbreviated).year()),
                              session: s)
                }
                if let s = bestAerobicSession, let hr = s.avgHeartRate {
                    Divider().padding(.leading, 54)
                    recordRow(icon: "heart.fill", color: .pink,
                              label: "Lowest HR Run", value: "\(Int(hr)) bpm",
                              sub: "Aerobic efficiency · " + s.formattedDistance(useKm: useKm),
                              session: s)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground),
                        in: RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    static func formatPaceShort(_ secPerKm: Double, useKm: Bool) -> String {
        let pace = useKm ? secPerKm : secPerKm * 1.60934
        guard pace > 0 else { return "--" }
        return String(format: "%d:%02d", Int(pace) / 60, Int(pace) % 60)
    }

    private static func recordRow(icon: String, color: Color, label: String,
                                  value: String, sub: String, session: CardioSession) -> some View {
        NavigationLink(destination: CardioSessionDetailView(session: session)) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                        .shadow(color: color.opacity(0.40), radius: 5, y: 2)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                    Text(sub)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14).padding(.vertical, 13)
        }
        .buttonStyle(.pressableCard)
    }
}
