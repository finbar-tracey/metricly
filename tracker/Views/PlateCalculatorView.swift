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
            LinearGradient(colors: [Color.indigo, Color.purple.opacity(0.7)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle().fill(.white.opacity(0.07)).frame(width: 200).offset(x: 160, y: -60)

            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    TextField("0", text: $targetWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 64, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 220)
                    Text(unit.label)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.70))
                }

                Text("Target Weight")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.75))

                HStack(spacing: 0) {
                    Text("Bar weight")
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    HStack(spacing: 12) {
                        Button {
                            if barWeight >= 2.5 { barWeight -= 2.5 }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3).foregroundStyle(.white.opacity(0.80))
                        }
                        .buttonStyle(.plain)

                        Text(unit.format(barWeight))
                            .font(.subheadline.bold().monospacedDigit())
                            .foregroundStyle(.white)
                            .frame(minWidth: 54)

                        Button {
                            if barWeight <= 57.5 { barWeight += 2.5 }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3).foregroundStyle(.white.opacity(0.80))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
            }
            .padding(20)
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
                    HStack(spacing: 14) {
                        Circle()
                            .fill(plateColors[plate] ?? .gray)
                            .frame(width: 32, height: 32)
                            .overlay { Circle().stroke(.primary.opacity(0.2), lineWidth: 1) }
                        Text("\(items.count)× \(unit.format(plate))")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text(unit.format(plate * Double(items.count) * 2) + " total")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    if idx < sorted.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

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
                Circle().fill(Color.indigo.opacity(0.12)).frame(width: 48, height: 48)
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 20, weight: .semibold)).foregroundStyle(.indigo)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Just the bar!").font(.subheadline.weight(.semibold))
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
                        targetWeight = String(format: "%.0f", unit.display(w))
                    } label: {
                        Text(unit.formatShort(w))
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity).padding(.vertical, 11)
                            .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(Color.indigo)
                    }
                    .buttonStyle(.plain)
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
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    ForEach(Array(platesPerSide.reversed().enumerated()), id: \.offset) { _, plate in
                        let heightRatio = max(0.3, plate / maxPlateWeight)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(plateColors[plate] ?? .gray)
                            .overlay { RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.2), lineWidth: 0.5) }
                            .frame(width: max(8, sideWidth / CGFloat(max(platesPerSide.count, 1)) - 2),
                                   height: geo.size.height * heightRatio)
                    }
                }
                .frame(width: sideWidth)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray3))
                    .frame(width: barWidth, height: 14)

                HStack(spacing: 2) {
                    ForEach(Array(platesPerSide.enumerated()), id: \.offset) { _, plate in
                        let heightRatio = max(0.3, plate / maxPlateWeight)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(plateColors[plate] ?? .gray)
                            .overlay { RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.2), lineWidth: 0.5) }
                            .frame(width: max(8, sideWidth / CGFloat(max(platesPerSide.count, 1)) - 2),
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
