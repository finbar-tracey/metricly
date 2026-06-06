import SwiftUI

enum WeeklyMonthlyReportHeroSections {

    static func periodPickerCard(selectedPeriod: Binding<ReportPeriod>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Period", icon: "calendar", color: .accentColor)
            HStack(spacing: 8) {
                ForEach(ReportPeriod.allCases, id: \.self) { period in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedPeriod.wrappedValue = period }
                    } label: {
                        Text(period.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background(selectedPeriod.wrappedValue == period ? Color.accentColor : Color(.secondarySystemFill),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(selectedPeriod.wrappedValue == period ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .appCard()
    }

    static func heroCard(snapshot: WeeklyMonthlyReportSnapshot, displayVolume: Double, weightUnit: WeightUnit) -> some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    Text(snapshot.vibeEmoji)
                        .font(.system(size: 42))
                        .padding(8)
                        .background(.ultraThinMaterial.opacity(0.7), in: Circle())
                        .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.period == .week ? "Weekly Report" : "Monthly Report")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                        Text(snapshot.periodLabel)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    if snapshot.prsHitCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill").font(.caption.bold())
                            Text("\(snapshot.prsHitCount) PR\(snapshot.prsHitCount == 1 ? "" : "s")").font(.caption.bold())
                        }
                        .padding(.horizontal, 11).padding(.vertical, 6)
                        .background(.ultraThinMaterial.opacity(0.7), in: Capsule())
                        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        .foregroundStyle(.white)
                    }
                }

                if snapshot.periodWorkoutsEmpty {
                    Text("No workouts logged \(snapshot.period == .week ? "this week" : "this month") yet.")
                        .font(.subheadline).foregroundStyle(.white.opacity(0.78))
                } else {
                    HStack(spacing: 0) {
                        HeroStatCol(value: "\(snapshot.workoutCount)", label: "Workouts")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                        HeroStatCol(value: "\(snapshot.totalSets)", label: "Sets")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                        HeroStatCol(value: snapshot.formattedDuration, label: "Duration")
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                        HeroStatCol(value: formatVolume(displayVolume, weightUnit: weightUnit), label: "Volume")
                    }
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.18), lineWidth: 0.5)
                    )
                }
            }
            .padding(20)
        }
    }

    @ViewBuilder
    static func trainingSummaryCard(snapshot: WeeklyMonthlyReportSnapshot, displayVolume: Double, weightUnit: WeightUnit) -> some View {
        if !snapshot.periodWorkoutsEmpty {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "Training Summary", icon: "figure.strengthtraining.traditional", color: .accentColor)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    statTile(icon: "dumbbell.fill", value: "\(snapshot.workoutCount)", label: "Workouts", color: .blue)
                    statTile(icon: "clock.fill", value: snapshot.formattedDuration, label: "Total Time", color: .green)
                    statTile(icon: "scalemass.fill", value: formatVolume(displayVolume, weightUnit: weightUnit), label: "Volume", color: .purple, change: snapshot.volumeChange)
                    statTile(icon: "number", value: "\(snapshot.totalSets)", label: "Sets", color: .orange)
                }
            }
            .appCard()
        }
    }

    static func formatVolume(_ volume: Double, weightUnit: WeightUnit) -> String {
        if volume >= 1000 { return String(format: "%.1fk %@", volume / 1000, weightUnit.label) }
        return String(format: "%.0f %@", volume, weightUnit.label)
    }

    static func statTile(icon: String, value: String, label: String, color: Color, change: Double? = nil) -> some View {
        VStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(LinearGradient(colors: [color, color.opacity(0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .shadow(color: color.opacity(0.40), radius: 6, y: 2)
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.secondary)
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right").imageScale(.small)
                    Text(String(format: "%+.0f%%", change))
                }
                .font(.caption2.bold())
                .foregroundStyle(change >= 0 ? .green : .red)
                .padding(.horizontal, 7).padding(.vertical, 2)
                .background((change >= 0 ? Color.green : Color.red).opacity(0.12), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [color.opacity(0.10), Color(.tertiarySystemGroupedBackground)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                .stroke(color.opacity(0.18), lineWidth: 0.5)
        )
    }
}
