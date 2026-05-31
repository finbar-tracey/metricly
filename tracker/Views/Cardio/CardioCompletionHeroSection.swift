import SwiftUI

/// Hero, stats, mini-stats, HR effort, and PR rows for cardio completion.
enum CardioCompletionHeroSection {
    @ViewBuilder
    static func content<HRBar: View>(
        session: CardioSession,
        useKm: Bool,
        prs: [CardioPR],
        appeared: Bool,
        settingsArray: [UserSettings],
        @ViewBuilder hrEffortBar: () -> HRBar
    ) -> some View {
        VStack(spacing: 28) {
            Spacer(minLength: 60)
            heroIcon(prs: prs, appeared: appeared)
            headline(session: session, prs: prs, appeared: appeared)
            statsStrip(session: session, useKm: useKm, appeared: appeared)
            miniStatsRow(session: session, useKm: useKm, settingsArray: settingsArray, appeared: appeared)
            hrEffortBar()
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.4).delay(0.46), value: appeared)
            if !prs.isEmpty {
                prList(prs: prs, appeared: appeared)
            }
        }
    }

    private static func heroIcon(prs: [CardioPR], appeared: Bool) -> some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial.opacity(0.7))
                .frame(width: 116, height: 116)
                .overlay(Circle().stroke(.white.opacity(0.30), lineWidth: 0.8))
            Circle().fill(.white.opacity(0.18)).frame(width: 86, height: 86)
            Image(systemName: prs.isEmpty ? "checkmark.circle.fill" : "trophy.fill")
                .font(.system(size: 50, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        }
        .scaleEffect(appeared ? 1 : 0.4)
        .animation(.spring(response: 0.55, dampingFraction: 0.65).delay(0.1), value: appeared)
    }

    private static func headline(session: CardioSession, prs: [CardioPR], appeared: Bool) -> some View {
        VStack(spacing: 8) {
            Text(prs.isEmpty ? "Session Complete!" : "New Record!")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)
            Text(session.date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.75))
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)
    }

    private static func statsStrip(session: CardioSession, useKm: Bool, appeared: Bool) -> some View {
        HStack(spacing: 0) {
            completionStat(label: "Distance", value: session.formattedDistance(useKm: useKm))
            Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 40)
            completionStat(label: "Duration", value: session.formattedDuration)
            Rectangle().fill(.white.opacity(0.3)).frame(width: 1, height: 40)
            completionStat(label: "Avg Pace", value: session.formattedPace(useKm: useKm))
        }
        .padding(.vertical, 16)
        .background(.ultraThinMaterial.opacity(0.6), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.35), value: appeared)
    }

    private static func miniStatsRow(
        session: CardioSession,
        useKm: Bool,
        settingsArray: [UserSettings],
        appeared: Bool
    ) -> some View {
        HStack(spacing: 12) {
            let cal = session.caloriesBurned ?? session.estimatedCalories()
            if cal > 0 {
                miniStat(icon: "flame.fill", value: String(format: "%.0f", cal), label: "kcal", color: .orange)
            }
            miniStat(icon: "flag.checkered", value: "\(session.splits.count)", label: "splits", color: .white.opacity(0.8))
            if session.elevationGainMeters > 1 {
                miniStat(icon: "arrow.up.right", value: String(format: "%.0f m", session.elevationGainMeters), label: "gain", color: .white.opacity(0.8))
            }
            if let hr = session.avgHeartRate {
                let zone = HRZone.zone(for: hr, maxHR: settingsArray.first?.resolvedMaxHR)
                miniStat(icon: "heart.fill", value: "\(Int(hr))",
                         label: "Z\(zone.number) · \(zone.rawValue)", color: zone.color)
            }
        }
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.4), value: appeared)
    }

    private static func prList(prs: [CardioPR], appeared: Bool) -> some View {
        VStack(spacing: 10) {
            ForEach(prs) { pr in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 44, height: 44)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: pr.icon)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(pr.label.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.4)
                            .foregroundStyle(.white.opacity(0.78))
                        Text(pr.value)
                            .font(.system(size: 16, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.system(size: 16, weight: .bold))
                        .shadow(color: .yellow.opacity(0.5), radius: 4)
                }
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 0.5)
                )
            }
        }
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.5), value: appeared)
    }

    private static func completionStat(label: String, value: String) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.78))
        }
        .frame(maxWidth: .infinity)
    }

    private static func miniStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.5)
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(.horizontal, 13).padding(.vertical, 9)
        .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.white.opacity(0.20), lineWidth: 0.5)
        )
    }
}
