import SwiftUI

enum BodyFatHeroSections {

    static func setupRequiredCard(sexConfigured: Bool, heightCm: Double) -> some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.orange.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "person.crop.circle.badge.exclamationmark")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.orange)
            }
            VStack(spacing: 6) {
                Text("Profile Setup Required").font(.headline)
                VStack(spacing: 4) {
                    if !sexConfigured {
                        Label("Set your biological sex in Settings", systemImage: "person.fill")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if heightCm <= 0 {
                        Label("Set your height in Settings", systemImage: "ruler")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            Text("Update in Settings → Profile")
                .font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    static func measurementsNeededCard(
        isFemale: Bool,
        latestNeck: Double?,
        latestWaist: Double?,
        latestHips: Double?,
        isMetric: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Measurements Needed", icon: "ruler", color: .orange)

            VStack(spacing: 0) {
                measurementRow("Neck", value: latestNeck, isMetric: isMetric)
                Divider().padding(.leading, 16)
                measurementRow("Waist", value: latestWaist, isMetric: isMetric)
                if isFemale {
                    Divider().padding(.leading, 16)
                    measurementRow("Hips", value: latestHips, isMetric: isMetric)
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            Text("Log measurements in the Measurements tab.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .appCard()
    }

    @ViewBuilder
    static func heroCard(
        bodyFatPercentage: Double?,
        category: (label: String, color: Color)
    ) -> some View {
        if let bf = bodyFatPercentage {
            let catColor = category.color
            HeroCard(palette: [catColor, catColor.opacity(0.78), catColor.opacity(0.55)]) {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center, spacing: 20) {
                        ZStack {
                            Circle().stroke(.white.opacity(0.25), lineWidth: 9)
                            Circle()
                                .trim(from: 0, to: min(1, bf / 50))
                                .stroke(.white, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                                .animation(.easeInOut(duration: 0.8), value: bf)
                                .shadow(color: .white.opacity(0.45), radius: 6, y: 1)
                        }
                        .frame(width: 70, height: 70)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Body Fat")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.82))
                                .tracking(0.5)
                                .textCase(.uppercase)
                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(String(format: "%.1f", bf))
                                    .font(.system(size: 54, weight: .black, design: .rounded))
                                    .foregroundStyle(.white)
                                    .monospacedDigit()
                                    .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                                Text("%")
                                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.78))
                            }
                        }
                        Spacer()
                    }

                    Text(category.label)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))

                    Text("Estimated using the U.S. Navy method")
                        .font(.caption).foregroundStyle(.white.opacity(0.78))
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    static func compositionCard(
        leanMassKg: Double?,
        fatMassKg: Double?,
        latestWeight: Double?,
        weightUnit: WeightUnit,
        category: (label: String, color: Color)
    ) -> some View {
        if let lean = leanMassKg, let fat = fatMassKg, let total = latestWeight {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Body Composition", icon: "figure.stand", color: category.color)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    compTile("Lean Mass", value: weightUnit.format(lean), color: .blue)
                    compTile("Fat Mass", value: weightUnit.format(fat), color: .orange)
                    compTile("Total", value: weightUnit.format(total), color: .secondary)
                }

                GeometryReader { geo in
                    let leanFraction = total > 0 ? lean / total : 0.5
                    HStack(spacing: 3) {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.blue, AppTheme.Signal.calm],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * leanFraction)
                            .shadow(color: .blue.opacity(0.40), radius: 4, y: 1)
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.orange, AppTheme.Signal.actionOrange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .orange.opacity(0.40), radius: 4, y: 1)
                    }
                }
                .frame(height: 22)

                HStack {
                    Label("LEAN", systemImage: "circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.blue)
                    Spacer()
                    Label("FAT", systemImage: "circle.fill")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.orange)
                }
            }
            .appCard()
        }
    }

    private static func compTile(_ title: String, value: String, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded).monospacedDigit())
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }

    private static func measurementRow(_ site: String, value: Double?, isMetric: Bool) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(value != nil ? Color.green.opacity(0.12) : Color(.systemFill)).frame(width: 34, height: 34)
                Image(systemName: value != nil ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(value != nil ? .green : .secondary)
            }
            Text(site).font(.subheadline)
            Spacer()
            if let value {
                Text(BodyFatChartSections.formatLength(value, isMetric: isMetric)).font(.subheadline).foregroundStyle(.secondary)
            } else {
                Text("Not logged").font(.caption).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }
}
