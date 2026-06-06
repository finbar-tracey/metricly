import SwiftUI
import Charts

enum OneRepMaxSections {

    static func exercisePickerCard(
        exerciseNames: [String],
        selectedExercise: Binding<String?>
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Exercise", icon: "dumbbell.fill", color: .blue)

            if exerciseNames.isEmpty {
                Text("Complete some workouts to see estimated 1RM data.")
                    .font(.subheadline).foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(exerciseNames.prefix(20), id: \.self) { name in
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedExercise.wrappedValue = name
                                }
                            } label: {
                                Text(name)
                                    .font(.caption.bold())
                                    .lineLimit(1)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background {
                                        if selectedExercise.wrappedValue == name {
                                            Capsule().fill(
                                                LinearGradient(
                                                    colors: [.blue, AppTheme.Signal.calm],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                )
                                            )
                                            .shadow(color: .blue.opacity(0.40), radius: 6, y: 3)
                                        } else {
                                            Capsule().fill(Color(.secondarySystemFill))
                                        }
                                    }
                                    .foregroundStyle(selectedExercise.wrappedValue == name ? Color.white : Color.primary)
                            }
                            .buttonStyle(.pressableCard)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    static func heroCard(
        exerciseName: String,
        currentE1RM: Double,
        peakE1RM: Double,
        sessionCount: Int,
        weightUnit: WeightUnit
    ) -> some View {
        HeroCard(palette: AppTheme.Gradients.calm) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.ultraThinMaterial.opacity(0.7))
                            .frame(width: 56, height: 56)
                            .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 0.5))
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(exerciseName)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .tracking(0.5)
                            .textCase(.uppercase)
                            .lineLimit(1)
                        Text(weightUnit.format(currentE1RM))
                            .font(.system(size: 42, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("PEAK")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.5)
                            .foregroundStyle(.white.opacity(0.78))
                        Text(weightUnit.format(peakE1RM))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 11).padding(.vertical, 8)
                    .background(.ultraThinMaterial.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.white.opacity(0.25), lineWidth: 0.5)
                    )
                }

                HStack(spacing: 0) {
                    HeroStatCol(value: "\(sessionCount)", label: "Sessions")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: weightUnit.format(currentE1RM), label: "Current")
                    Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 32)
                    HeroStatCol(value: weightUnit.format(peakE1RM), label: "Peak")
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

    static func chartCard(
        e1rmHistory: [(Date, Double)],
        weightUnit: WeightUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Estimated 1RM Trend", icon: "chart.line.uptrend.xyaxis", color: .blue)
            Chart(e1rmHistory, id: \.0) { point in
                AreaMark(x: .value("Date", point.0), y: .value("E1RM", weightUnit.display(point.1)))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.40), Color.blue.opacity(0.16), Color.blue.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                LineMark(x: .value("Date", point.0), y: .value("E1RM", weightUnit.display(point.1)))
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, AppTheme.Signal.calm],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .shadow(color: Color.blue.opacity(0.30), radius: 5, y: 2)
                PointMark(x: .value("Date", point.0), y: .value("E1RM", weightUnit.display(point.1)))
                    .foregroundStyle(Color.blue).symbolSize(25)
            }
            .chartYAxisLabel(weightUnit.label)
            .frame(height: 200)
            .padding(.vertical, 4)
        }
        .appCard()
    }

    static func formulaCard(
        formula: Binding<OneRepMaxEngine.Formula>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Formula", icon: "function", color: .blue)

            HStack(spacing: 8) {
                ForEach(OneRepMaxEngine.Formula.allCases, id: \.self) { f in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { formula.wrappedValue = f }
                    } label: {
                        Text(f.rawValue)
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 10)
                            .background {
                                if formula.wrappedValue == f {
                                    RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous).fill(
                                        LinearGradient(
                                            colors: [.blue, AppTheme.Signal.calm],
                                            startPoint: .topLeading, endPoint: .bottomTrailing
                                        )
                                    )
                                    .shadow(color: .blue.opacity(0.35), radius: 6, y: 3)
                                } else {
                                    RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous).fill(Color(.secondarySystemFill))
                                }
                            }
                            .foregroundStyle(formula.wrappedValue == f ? Color.white : Color.primary)
                    }
                    .buttonStyle(.pressableCard)
                }
            }

            Text(formula.wrappedValue == .epley
                 ? "Epley: weight × (1 + reps/30). Best for 1–10 rep ranges."
                 : "Brzycki: weight × 36/(37 − reps). Most accurate for lower rep sets.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .appCard()
    }

    static func percentageCard(
        percentageRows: [(label: String, value: Double)],
        weightUnit: WeightUnit
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Training Zones", icon: "percent", color: .blue)

            VStack(spacing: 0) {
                ForEach(Array(percentageRows.enumerated()), id: \.offset) { idx, row in
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [zoneColor(idx), zoneColor(idx).opacity(0.72)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                                .shadow(color: zoneColor(idx).opacity(0.40), radius: 5, y: 2)
                            Text(row.label)
                                .font(.system(size: 12, weight: .black, design: .rounded))
                                .foregroundStyle(.white)
                        }
                        Text(zoneLabel(idx))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(weightUnit.format(row.value))
                            .font(.system(size: 15, weight: .black, design: .rounded).monospacedDigit())
                            .foregroundStyle(zoneColor(idx))
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                    if idx < percentageRows.count - 1 { Divider().padding(.leading, 70) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(AppTheme.cardHairline, lineWidth: 0.5)
            )
        }
        .appCard()
    }

    static func emptyExerciseCard() -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.26), Color.blue.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(Color.blue.opacity(0.28), lineWidth: 0.5))
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24, weight: .semibold)).foregroundStyle(.blue)
            }
            Text("No data for this exercise yet.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 32)
        .appCard()
    }

    static func noDataCard() -> some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.26), Color.blue.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                    .overlay(Circle().stroke(Color.blue.opacity(0.28), lineWidth: 0.5))
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(.blue)
            }
            VStack(spacing: 6) {
                Text("No Workout Data").font(.headline)
                Text("Complete some workouts to calculate your estimated 1RM.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Private

    private static func zoneColor(_ index: Int) -> Color {
        [Color.blue, .cyan, .green, .green, .yellow, .orange, .orange, .red, .red][min(index, 8)]
    }

    private static func zoneLabel(_ index: Int) -> String {
        ["Max", "Strength", "Strength", "Hypertrophy", "Hypertrophy", "Endurance", "Endurance", "Warm-up", "Warm-up"][min(index, 8)]
    }
}
