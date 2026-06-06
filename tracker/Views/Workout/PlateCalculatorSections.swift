import SwiftUI

enum PlateCalculatorSections {

    private static let plateColors: [Double: Color] = [
        25: .red, 20: .blue, 15: .yellow, 10: .green, 5: .white, 2.5: .red.opacity(0.5), 1.25: .gray
    ]

    static func inputHeroCard(
        unit: WeightUnit,
        targetWeight: Binding<String>,
        barWeight: Binding<Double>
    ) -> some View {
        HeroCard(palette: [
            Color(red: 0.30, green: 0.20, blue: 0.85),
            Color(red: 0.55, green: 0.25, blue: 0.85),
            Color(red: 0.78, green: 0.30, blue: 0.78)
        ]) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Target Weight")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.82))
                    .tracking(0.5)
                    .textCase(.uppercase)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: targetWeight)
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
                            if barWeight.wrappedValue >= 2.5 { barWeight.wrappedValue -= 2.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.pressableCard)
                        .accessibilityLabel("Decrease bar weight")

                        Text(unit.format(barWeight.wrappedValue))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(minWidth: 54)

                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if barWeight.wrappedValue <= 57.5 { barWeight.wrappedValue += 2.5 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundStyle(.white.opacity(0.85))
                        }
                        .buttonStyle(.pressableCard)
                        .accessibilityLabel("Increase bar weight")
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.20), lineWidth: 0.5))
                }
                .padding(.top, 4)
            }
            .padding(22)
        }
    }

    static func plateResultCard(
        unit: WeightUnit,
        platesPerSide: [Double],
        targetKg: Double,
        actualWeightKg: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionHeader(title: "Load Per Side", icon: "dumbbell.fill", color: .indigo)
                Spacer()
                Text("\(unit.format(platesPerSide.reduce(0, +))) per side")
                    .font(.caption.bold().monospacedDigit()).foregroundStyle(.secondary)
            }

            barVisualization(platesPerSide: platesPerSide).frame(height: 110).padding(.vertical, 4)

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
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )

            HStack {
                if abs(actualWeightKg - targetKg) > 0.01 {
                    let delta = actualWeightKg - targetKg
                    let deltaText = delta > 0
                        ? "\(unit.format(abs(delta))) over"
                        : "\(unit.format(abs(delta))) short"
                    HStack(spacing: 5) {
                        Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                        Text("Closest loadable · \(deltaText)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text("Total: \(unit.format(actualWeightKg))")
                    .font(.subheadline.bold())
            }
        }
        .appCard()
    }

    static func justTheBarCard() -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
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

    static func quickSelectCard(unit: WeightUnit, onSelect: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Quick Select", icon: "bolt.fill", color: .indigo)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], spacing: 8) {
                ForEach(PlateCalculatorEngine.quickWeightsKg, id: \.self) { w in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        onSelect(w)
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

    private static func barVisualization(platesPerSide: [Double]) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let barWidth = totalWidth * 0.3
            let sideWidth = (totalWidth - barWidth) / 2
            let maxPlateWeight = PlateCalculatorEngine.availablePlatesKg.first ?? 25

            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(.systemGray3), Color(.systemGray2), Color(.systemGray3)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 8)
                    .shadow(color: .black.opacity(0.12), radius: 2, y: 1)

                HStack(spacing: 0) {
                    HStack(spacing: 3) {
                        Spacer(minLength: 0)
                        ForEach(Array(platesPerSide.reversed().enumerated()), id: \.offset) { _, plate in
                            plateView(plate, sideWidth: sideWidth, maxHeight: geo.size.height, maxPlateWeight: maxPlateWeight, plateCount: platesPerSide.count)
                        }
                        collar(maxHeight: geo.size.height)
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
                        collar(maxHeight: geo.size.height)
                        ForEach(Array(platesPerSide.enumerated()), id: \.offset) { _, plate in
                            plateView(plate, sideWidth: sideWidth, maxHeight: geo.size.height, maxPlateWeight: maxPlateWeight, plateCount: platesPerSide.count)
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(width: sideWidth)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
    }

    private static func plateView(
        _ plate: Double,
        sideWidth: CGFloat,
        maxHeight: CGFloat,
        maxPlateWeight: Double,
        plateCount: Int
    ) -> some View {
        let heightRatio = max(0.3, plate / maxPlateWeight)
        let plateColor = plateColors[plate] ?? .gray
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [plateColor, plateColor.opacity(0.78)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(.white.opacity(0.30), lineWidth: 0.5)
            }
            .shadow(color: plateColor.opacity(0.45), radius: 4, y: 2)
            .frame(width: max(8, sideWidth / CGFloat(max(plateCount, 1)) - 3),
                   height: maxHeight * heightRatio)
    }

    private static func collar(maxHeight: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(.systemGray), Color(.systemGray2)],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .frame(width: 6, height: maxHeight * 0.46)
            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            .padding(.horizontal, 1)
    }
}
