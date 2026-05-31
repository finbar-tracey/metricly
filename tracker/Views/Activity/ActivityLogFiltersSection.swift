import SwiftUI

enum ActivityLogFiltersSection {

    static func heroCard(
        todayMinutes: Int,
        todayCount: Int,
        thisWeekMinutes: Int,
        thisWeekTotalCount: Int
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.recovery) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "figure.mixed.cardio")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Today's Activity")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            AnimatedInt(
                                value: todayMinutes,
                                font: .system(size: 42, weight: .black, design: .rounded),
                                color: .white
                            )
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                            Text("min")
                                .font(.system(size: 18, weight: .heavy, design: .rounded))
                                .foregroundStyle(.white.opacity(0.78))
                        }
                    }
                    Spacer()
                    if todayCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill").font(.caption.bold())
                            Text("\(todayCount) logged").font(.caption.bold())
                        }
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .foregroundStyle(.white)
                    }
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(thisWeekMinutes)m", label: "This Week")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(thisWeekTotalCount)", label: "Activities")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: "\(todayMinutes)m", label: "Today")
                }
                .padding(.vertical, 10)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(20)
        }
    }

    static func quickLogCard(onSelectType: @escaping (ManualActivity.ActivityType) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Log Activity", icon: "plus.circle.fill", color: .green)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(ManualActivity.ActivityType.allCases) { type in
                        Button {
                            onSelectType(type)
                        } label: {
                            VStack(spacing: 5) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(colorFor(type).opacity(0.12))
                                        .frame(width: 52, height: 52)
                                    Image(systemName: type.icon)
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(colorFor(type))
                                }
                                Text(type.rawValue)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                            }
                            .frame(width: 64)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    private static func colorFor(_ type: ManualActivity.ActivityType) -> Color {
        switch type.color {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "cyan": return .cyan
        case "brown": return .brown
        case "purple": return .purple
        case "indigo": return .indigo
        case "red": return .red
        default: return .gray
        }
    }
}
