import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.weightUnit) private var unit
    @State private var targetWeight: String = ""
    @State private var barWeight: Double = 20.0

    private var availablePlatesKg: [Double] { [25, 20, 15, 10, 5, 2.5, 1.25] }
    private var availablePlatesLbs: [Double] { [45, 35, 25, 10, 5, 2.5] }

    private var targetKg: Double {
        guard let value = Double(targetWeight), value > 0 else { return 0 }
        return unit.toKg(value)
    }

    private var platesPerSide: [Double] {
        let remaining = targetKg - barWeight
        guard remaining > 0 else { return [] }
        var perSide = remaining / 2.0
        var result: [Double] = []
        for plate in availablePlatesKg {
            while perSide >= plate - 0.001 { result.append(plate); perSide -= plate }
        }
        return result
    }

    private var actualWeight: Double { barWeight + platesPerSide.reduce(0, +) * 2 }

    private var plateColors: [Double: Color] {
        [25: .red, 20: .blue, 15: .yellow, 10: .green, 5: .white, 2.5: .red.opacity(0.5), 1.25: .gray]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                inputHeroCard

                if !platesPerSide.isEmpty {
                    plateResultCard
                } else if targetKg > 0 && targetKg <= barWeight {
                    justTheBarCard
                }

                quickSelectCard
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Plate Calculator")
    }

    // MARK: - Input Hero Card

    private var inputHeroCard: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [
                    Color(red: 0.30, green: 0.20, blue: 0.85),
                    Color(red: 0.55, green: 0.25, blue: 0.85),
                    Color(red: 0.78, green: 0.30, blue: 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            // Top sheen
            LinearGradient(
                colors: [.white.opacity(0.18), .clear],
                startPoint: .top, endPoint: .center
            )
            .blendMode(.plusLighter)
            Circle().fill(.white.opacity(0.10)).frame(width: 200).blur(radius: 12).offset(x: 160, y: -60)
            Circle().fill(.white.opacity(0.06)).frame(width: 110).blur(radius: 10).offset(x: -30, y: 80)

            VStack(alignment: .leading, spacing: 18) {
                Text("Target Weight")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .tracking(0.5)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $targetWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 72, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 220)
                        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
                    Text(unit.label)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white.opacity(0.78))
                }

                HStack(spacing: 0) {
                    Text("Bar weight")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if barWeight >= 2.5 { barWeight -= 2.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.pressableCard)

                        Text(unit.format(barWeight))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(minWidth: 54)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if barWeight <= 57.5 { barWeight += 2.5 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.pressableCard)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 0.5))
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
        .heroCard()
    }

    // MARK: - Plate Result Card

    private var plateResultCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Load Per Side", icon: "dumbbell.fill", color: .indigo)
                Spacer()
                Text("\(unit.format(platesPerSide.reduce(0, +))) per side")
                    .font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
            }

            barVisualization.frame(height: 110).padding(.vertical, 4)

            Divider()

            let grouped = Dictionary(grouping: platesPerSide, by: { $0 })
            let sorted = grouped.sorted { $0.key > $1.key }

            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.key) { idx, pair in
                    let (plate, items) = pair
                    let pColor = plateColors[plate] ?? .gray
                    HStack(spacing: 14) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [pColor, pColor.opacity(0.78)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(.white.opacity(0.30), lineWidth: 1))
                            .shadow(color: pColor.opacity(0.40), radius: 5, y: 2)
                        Text("\(items.count)× \(unit.format(plate))")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                        Spacer()
                        Text(unit.format(plate * Double(items.count) * 2) + " total")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    if idx < sorted.count - 1 { Divider().padding(.leading, 66) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )

            HStack {
                if abs(actualWeight - targetKg) > 0.01 {
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                        Text("Closest loadable weight").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("Total: \(unit.format(actualWeight))")
                    .font(.subheadline.bold())
            }
        }
        .appCard()
    }

    // MARK: - Just the Bar Card

    private var justTheBarCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.indigo, Color(red: 0.40, green: 0.30, blue: 0.92)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 52, height: 52)
                    .shadow(color: .indigo.opacity(0.40), radius: 6, y: 3)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Just the bar!")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text("Target is at or below the bar weight.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .appCard()
    }

    // MARK: - Quick Select Card

    private var quickSelectCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Select", icon: "bolt.fill", color: .indigo)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(quickWeights, id: \.self) { w in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        targetWeight = String(format: "%.0f", unit.display(w))
                    } label: {
                        Text(unit.formatShort(w))
                            .font(.system(size: 15, weight: .black, design: .rounded))
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.indigo.opacity(0.20), Color.indigo.opacity(0.10)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.indigo.opacity(0.20), lineWidth: 0.5)
                            )
                            .foregroundStyle(Color.indigo)
                    }
                    .buttonStyle(.pressableCard)
                }
            }
        }
        .appCard()
    }

    // MARK: - Bar Visualization

    private var barVisualization: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let barWidth = totalWidth * 0.3
            let sideWidth = (totalWidth - barWidth) / 2
            let maxPlateWeight = availablePlatesKg.first ?? 25

            HStack(spacing: 0) {
                HStack(spacing: 3) {
                    Spacer(minLength: 0)
                    ForEach(Array(platesPerSide.reversed().enumerated()), id: \.offset) { _, plate in
                        let heightRatio = max(0.3, plate / maxPlateWeight)
                        let plateColor = plateColors[plate] ?? .gray
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [plateColor, plateColor.opacity(0.78)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(.white.opacity(0.30), lineWidth: 0.5)
                            }
                            .shadow(color: plateColor.opacity(0.45), radius: 4, y: 2)
                            .frame(width: max(8, sideWidth / CGFloat(max(platesPerSide.count, 1)) - 3),
                                   height: geo.size.height * heightRatio)
                    }
                }
                .frame(width: sideWidth)

                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray2), Color(.systemGray3), Color(.systemGray2)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: barWidth, height: 16)
                    .shadow(color: .black.opacity(0.18), radius: 3, y: 1)

                HStack(spacing: 3) {
                    ForEach(Array(platesPerSide.enumerated()), id: \.offset) { _, plate in
                        let heightRatio = max(0.3, plate / maxPlateWeight)
                        let plateColor = plateColors[plate] ?? .gray
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [plateColor, plateColor.opacity(0.78)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .stroke(.white.opacity(0.30), lineWidth: 0.5)
                            }
                            .shadow(color: plateColor.opacity(0.45), radius: 4, y: 2)
                            .frame(width: max(8, sideWidth / CGFloat(max(platesPerSide.count, 1)) - 3),
                                   height: geo.size.height * heightRatio)
                    }
                    Spacer(minLength: 0)
                }
                .frame(width: sideWidth)
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private var quickWeights: [Double] { [40, 60, 80, 100, 120, 140, 160, 180] }
}

#Preview {
    NavigationStack { PlateCalculatorView() }
        .environment(\.weightUnit, .kg)
}
