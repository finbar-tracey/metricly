import SwiftUI

enum CaffeineIntakeCardsSection {

    static func streakCard(streak: Int, daysSinceFreeDayText: String?) -> some View {
        HStack(spacing: 16) {
            if streak > 0 {
                gradientDisc("leaf.fill", color: .green, size: 48, glyph: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(streak) caffeine-free day\(streak == 1 ? "" : "s")")
                        .font(.subheadline.weight(.semibold))
                    Text("Keep it going!").font(.caption).foregroundStyle(.secondary)
                }
            } else if let lastFree = daysSinceFreeDayText {
                gradientDisc("cup.and.saucer.fill", color: .brown, size: 48, glyph: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Last caffeine-free day").font(.subheadline.weight(.semibold))
                    Text(lastFree).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .appCard()
    }

    static func recentIntakeCard(
        entries: [CaffeineEntry],
        halfLife: Double,
        onEdit: @escaping (CaffeineEntry) -> Void,
        onDelete: @escaping (CaffeineEntry) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Recent Intake", icon: "clock.fill", color: .secondary)
            VStack(spacing: 0) {
                ForEach(Array(entries.prefix(20).enumerated()), id: \.element.id) { idx, entry in
                    Button { onEdit(entry) } label: {
                        intakeRowContent(entry, halfLife: halfLife)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button { onEdit(entry) } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive) { onDelete(entry) } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    if idx < min(entries.count, 20) - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    static func timeOfDayCard(breakdown: [CaffeineEngine.TimeOfDaySlice]) -> some View {
        let colors: [String: Color] = [
            "Morning": .orange, "Afternoon": .yellow, "Evening": .indigo, "Night": .purple
        ]
        let maxMg = breakdown.map(\.mg).max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "When You Drink (30 Days)", icon: "clock.fill", color: .brown)
            VStack(spacing: 10) {
                ForEach(breakdown) { item in
                    let color = colors[item.period] ?? .brown
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [color.opacity(0.26), color.opacity(0.12)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 28, height: 28)
                                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(color.opacity(0.28), lineWidth: 0.5))
                            Image(systemName: item.icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(color)
                        }
                        Text(item.period).font(.caption).frame(width: 65, alignment: .leading)
                        GeometryReader { geo in
                            let width = max(0, geo.size.width * (maxMg > 0 ? item.mg / maxMg : 0))
                            RoundedRectangle(cornerRadius: 4).fill(color.gradient).frame(width: width)
                        }
                        .frame(height: 16)
                        Text("\(Int(item.mg))mg")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: 50, alignment: .trailing)
                    }
                }
            }
        }
        .appCard()
    }

    private static func intakeRowContent(_ entry: CaffeineEntry, halfLife: Double) -> some View {
        let preset = CaffeineEntry.presets.first { $0.name == entry.source }
        return HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.brown.opacity(0.26), Color.brown.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.brown.opacity(0.28), lineWidth: 0.5))
                Image(systemName: preset?.icon ?? "pill.fill")
                    .font(.system(size: 14, weight: .semibold)).foregroundStyle(.brown)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.source).font(.subheadline.weight(.semibold)).foregroundStyle(.primary)
                Text(entry.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(entry.milligrams)) mg").font(.subheadline.bold().monospacedDigit()).foregroundStyle(.primary)
                let remaining = entry.remainingCaffeine(halfLifeHours: halfLife)
                if remaining > 0.5 {
                    Text("\(Int(remaining)) mg left").font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Metabolized").font(.caption).foregroundStyle(.green)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}
