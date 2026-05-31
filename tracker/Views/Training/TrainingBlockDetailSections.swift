import SwiftUI

enum TrainingBlockDetailSections {

    static func headerCard(
        block: TrainingBlock,
        palette: Color,
        progressLabel: String,
        dateRangeLabel: String,
        isActive: Bool,
        daysRemaining: Int
    ) -> some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(palette.opacity(0.18))
                        .frame(width: 48, height: 48)
                    Image(systemName: block.phase.icon)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(palette)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.phase.label)
                        .font(.title3.weight(.bold))
                    Text(block.phase.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progressLabel)
                        .font(.headline.weight(.bold))
                    Text(dateRangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(daysRemaining)")
                            .font(.title2.weight(.black).monospacedDigit())
                            .foregroundStyle(palette)
                        Text(daysRemaining == 1 ? "day left" : "days left")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                    }
                }
            }
        }
        .appCard()
    }

    static func notesCard(notesDraft: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Notes")
                    .font(.subheadline.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            TextField(
                "Why this block? Any focus or context.",
                text: notesDraft,
                axis: .vertical
            )
            .lineLimit(3...6)
            .font(.body)
        }
        .appCard()
    }

    static func actionsCard(
        isActive: Bool,
        palette: Color,
        nextPhaseLabel: String,
        nextRationale: String,
        onEndEarly: @escaping () -> Void,
        onStartNext: @escaping () -> Void
    ) -> some View {
        VStack(spacing: 10) {
            if isActive {
                Button(role: .destructive, action: onEndEarly) {
                    actionRow(
                        icon: "calendar.badge.minus",
                        palette: palette,
                        title: "End block early",
                        subtitle: "Finish at the end of today"
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onStartNext) {
                    actionRow(
                        icon: "calendar.badge.plus",
                        palette: palette,
                        title: "Start \(nextPhaseLabel.lowercased())",
                        subtitle: nextRationale
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .appCard()
    }

    static func historyCard(
        pastBlocks: [TrainingBlock],
        paletteForPhase: @escaping (TrainingBlock.Phase) -> Color,
        formatRange: @escaping (Date, Date) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Past blocks")
                    .font(.subheadline.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            VStack(spacing: 8) {
                ForEach(pastBlocks.prefix(6), id: \.id) { past in
                    historyRow(past, palette: paletteForPhase(past.phase), formatRange: formatRange)
                }
            }
        }
        .appCard()
    }

    static func actionRow(icon: String, palette: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(palette)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private static func historyRow(
        _ past: TrainingBlock,
        palette: Color,
        formatRange: (Date, Date) -> String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: past.phase.icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(past.phase.label) · \(past.weekCount)w")
                    .font(.subheadline.weight(.semibold))
                Text(formatRange(past.startDate, past.endDate))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}
