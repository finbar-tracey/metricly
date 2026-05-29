import SwiftUI
import SwiftData

/// Confirmation sheet shown after the user picks a Strong/Hevy CSV
/// from Settings, before any rows are inserted into SwiftData. Shows
/// what the parser found (format, totals, earliest date, sample of
/// the first workout) so users can spot a bad file (e.g., they
/// exported the wrong app's CSV by mistake) before committing.
///
/// On confirm: runs `ImportHelper.commitPreview(_:into:)` and posts a
/// notification so the Settings caller can flip into its "success"
/// alert state. Cancellation just dismisses.
struct ImportPreviewSheet: View {
    let preview: ImportHelper.ImportPreview
    let onImport: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    statsCard
                    if let sample = preview.sampleWorkout {
                        sampleCard(sample)
                    }
                    disclaimer
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(String(localized: "Confirm import",
                                    comment: "Navigation title for the Strong/Hevy import preview sheet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Cancel",
                                  comment: "Cancel button on the import preview sheet"),
                           action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onImport()
                    } label: {
                        Text(String(localized: "Import",
                                    comment: "Confirm button on the import preview sheet"))
                            .font(.headline)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(formatColor.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(formatColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatTitle)
                        .font(.title3.weight(.bold))
                    Text(formatSubtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var formatTitle: String {
        switch preview.format {
        case .strong:   return String(localized: "From Strong",
                                      comment: "Title of the import preview sheet when the source is the Strong app")
        case .hevy:     return String(localized: "From Hevy",
                                      comment: "Title of the import preview sheet when the source is the Hevy app")
        case .metricly: return String(localized: "From Metricly",
                                      comment: "Title of the import preview sheet when re-importing a Metricly export")
        }
    }

    private var formatSubtitle: String {
        switch preview.format {
        case .strong:
            return String(localized: "Strong CSV export detected.",
                          comment: "Subtitle confirming the file format detected as Strong")
        case .hevy:
            return String(localized: "Hevy CSV export detected.",
                          comment: "Subtitle confirming the file format detected as Hevy")
        case .metricly:
            return String(localized: "Metricly CSV export detected.",
                          comment: "Subtitle confirming the file format detected as Metricly's own export")
        }
    }

    private var formatColor: Color {
        switch preview.format {
        case .strong:   return .orange
        case .hevy:     return .purple
        case .metricly: return .accentColor
        }
    }

    // MARK: - Stats card

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "What we found",
                        comment: "Section header above the import preview's totals row"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            HStack(spacing: 0) {
                statCol(label: String(localized: "Workouts",
                                      comment: "Stat label under the workout count in the import preview"),
                        value: "\(preview.workoutCount)")
                Divider().frame(height: 38)
                statCol(label: String(localized: "Exercises",
                                      comment: "Stat label under the unique exercise count"),
                        value: "\(preview.exerciseCount)")
                Divider().frame(height: 38)
                statCol(label: String(localized: "Sets",
                                      comment: "Stat label under the total set count"),
                        value: "\(preview.totalSetCount)")
            }
            .padding(.vertical, 6)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let earliest = preview.earliestDate {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(String(
                        localized: "History reaches back to \(earliest.formatted(date: .long, time: .omitted))",
                        comment: "Footnote in the import preview showing the earliest workout date"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .appCard()
    }

    private func statCol(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Sample workout

    private func sampleCard(_ sample: ParsedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "First workout in the file",
                        comment: "Section header above a sample of the first imported workout"))
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)

            VStack(alignment: .leading, spacing: 4) {
                Text(sample.title)
                    .font(.subheadline.weight(.semibold))
                Text(sample.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(sample.exercises.prefix(5).enumerated()), id: \.offset) { _, ex in
                    HStack(spacing: 10) {
                        Image(systemName: "dumbbell")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                            .frame(width: 18)
                        Text(ex.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(String(
                            localized: "\(ex.sets.count) sets",
                            comment: "Trailing set count on each row of the sample-workout list in the import preview"
                        ))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    if ex.name != sample.exercises.prefix(5).last?.name {
                        Divider().padding(.leading, 42)
                    }
                }
                if sample.exercises.count > 5 {
                    HStack {
                        Text(String(
                            localized: "+ \(sample.exercises.count - 5) more exercise(s)",
                            comment: "Footer row when the sample workout has more exercises than fit in the preview"
                        ))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(16)
        .appCard()
    }

    // MARK: - Disclaimer

    private var disclaimer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(String(
                localized: "Importing will add these workouts alongside what's already in Metricly — nothing is deleted or replaced.",
                comment: "Disclaimer under the import preview reminding the user that existing data is preserved"
            ))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}
