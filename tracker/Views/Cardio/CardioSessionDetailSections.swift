import SwiftUI

enum CardioSessionDetailSections {
    static func heroCard(session: CardioSession, useKm: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [session.type.color, session.type.color.opacity(0.65)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle().fill(.white.opacity(0.20)).frame(width: 40, height: 40)
                        Image(systemName: session.type.icon)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(session.type.rawValue.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.4)
                        Text(session.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                HStack(spacing: 0) {
                    HeroStatCol(value: session.formattedDistance(useKm: useKm), label: "Distance")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: session.formattedDuration, label: "Duration")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: session.formattedPace(useKm: useKm), label: "Avg Pace")
                }
                .padding(.vertical, 12)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.5)
                )
            }
            .padding(14)
        }
        .heroCard()
    }

    static func statsCard(session: CardioSession, useKm: Bool, resolvedMaxHR: Double?) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Stats", icon: "chart.bar.fill", color: session.type.color)
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                spacing: 12
            ) {
                statTile("Distance", value: session.formattedDistance(useKm: useKm), icon: "ruler", color: session.type.color)
                statTile("Duration", value: session.formattedDuration, icon: "clock", color: .blue)
                statTile("Avg Pace", value: session.formattedPace(useKm: useKm), icon: "speedometer", color: .purple)
                statTile("Splits", value: "\(session.splits.count)", icon: "flag.checkered", color: .orange)
                if session.elevationGainMeters > 0 {
                    statTile("Elevation", value: String(format: "%.0f m", session.elevationGainMeters), icon: "arrow.up.right", color: .teal)
                }
                if let hr = session.avgHeartRate, let maxHR = resolvedMaxHR {
                    let hrZone = HRZone.zone(for: hr, maxHR: maxHR)
                    statTile("Avg HR", value: "\(Int(hr)) bpm", icon: "heart.fill", color: hrZone.color)
                }
                let cal = session.caloriesBurned ?? session.estimatedCalories()
                if cal > 0 {
                    statTile("Calories", value: String(format: "%.0f kcal", cal), icon: "flame.fill", color: .orange)
                }
            }
        }
        .appCard()
    }

    static func hrZonesCard(breakdown: [(zone: HRZone, seconds: Double)]) -> some View {
        let total = breakdown.reduce(0) { $0 + $1.seconds }
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Heart Rate Zones", icon: "heart.fill", color: .red)
            VStack(spacing: 11) {
                ForEach(breakdown, id: \.zone) { item in
                    let pct = total > 0 ? item.seconds / total : 0
                    HStack(spacing: 12) {
                        Text("Z\(item.zone.number)")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(item.zone.color)
                            .frame(width: 26, alignment: .leading)
                        Text(item.zone.rawValue)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .frame(width: 66, alignment: .leading)
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(item.zone.color.opacity(0.16)).frame(height: 8)
                                Capsule().fill(item.zone.color)
                                    .frame(width: max(6, geo.size.width * pct), height: 8)
                            }
                        }
                        .frame(height: 8)
                        Text(formatZoneTime(item.seconds))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    static func hrZoneBreakdown(session: CardioSession, resolvedMaxHR: Double?) -> [(zone: HRZone, seconds: Double)] {
        guard let maxHR = resolvedMaxHR else { return [] }
        var totals: [HRZone: Double] = [:]
        for split in session.splits {
            guard let hr = split.avgHeartRate else { continue }
            totals[HRZone.zone(for: hr, maxHR: maxHR), default: 0] += split.durationSeconds
        }
        let order: [HRZone] = [.max, .threshold, .tempo, .aerobic, .easy]
        return order.compactMap { z in
            let s = totals[z] ?? 0
            return s > 0 ? (zone: z, seconds: s) : nil
        }
    }

    static func splitsCard(session: CardioSession, useKm: Bool) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Splits", icon: "flag.checkered", color: session.type.color)
            VStack(spacing: 0) {
                HStack {
                    Text("Split").font(.caption.bold()).frame(width: 40, alignment: .leading)
                    Spacer()
                    Text("Time").font(.caption.bold()).frame(width: 52, alignment: .trailing)
                    Text("Pace").font(.caption.bold()).frame(width: 72, alignment: .trailing)
                    if session.avgHeartRate != nil {
                        Text("HR").font(.caption.bold()).frame(width: 40, alignment: .trailing)
                    }
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                Divider()
                ForEach(session.splits) { split in
                    splitRow(split, session: session, useKm: useKm)
                    if split.id < session.splits.count { Divider().padding(.horizontal, 16) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    static func notesCard(notes: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notes", icon: "note.text", color: .secondary)
            Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private static func formatZoneTime(_ seconds: Double) -> String {
        let s = Int(seconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private static func statTile(_ title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(color.opacity(0.12)).frame(width: 34, height: 34)
                Image(systemName: icon).font(.system(size: 13, weight: .semibold)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value).font(.subheadline.bold().monospacedDigit()).lineLimit(1).minimumScaleFactor(0.75)
                Text(title).font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private static func splitRow(_ split: CardioSplit, session: CardioSession, useKm: Bool) -> some View {
        let paceRaw = useKm ? split.paceSecondsPerKm : split.paceSecondsPerMile
        let avgPace = useKm ? session.avgPaceSecPerKm : session.avgPaceSecPerMile
        let isFast = paceRaw < avgPace * 0.97
        let isSlow = paceRaw > avgPace * 1.03
        let zone = PaceZone.zone(for: split.paceSecondsPerKm)
        return HStack {
            HStack(spacing: 4) {
                Circle().fill(zone.color).frame(width: 7, height: 7)
                Text("\(split.id)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .frame(width: 22, alignment: .leading)
                if isFast {
                    Image(systemName: "arrow.up").font(.system(size: 8, weight: .bold)).foregroundStyle(.green)
                } else if isSlow {
                    Image(systemName: "arrow.down").font(.system(size: 8, weight: .bold)).foregroundStyle(.orange)
                }
            }
            .frame(width: 48, alignment: .leading)
            Spacer()
            Text(split.formattedDuration())
                .font(.subheadline.monospacedDigit())
                .frame(width: 52, alignment: .trailing)
            Text(split.formattedPace(useKm: useKm))
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(isFast ? .green : isSlow ? .orange : .primary)
                .frame(width: 72, alignment: .trailing)
            if session.avgHeartRate != nil {
                Text(split.avgHeartRate.map { "\(Int($0))" } ?? "--")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.red)
                    .frame(width: 40, alignment: .trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
