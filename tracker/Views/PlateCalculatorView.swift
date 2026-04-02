import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.weightUnit) private var unit
    @State private var targetWeight: String = ""
    @State private var barWeight: Double = 20.0 // kg

    private var availablePlatesKg: [Double] {
        [25, 20, 15, 10, 5, 2.5, 1.25]
    }

    private var availablePlatesLbs: [Double] {
        [45, 35, 25, 10, 5, 2.5]
    }

    private var plates: [Double] {
        unit == .kg ? availablePlatesKg : availablePlatesLbs
    }

    private var barWeightDisplay: Double {
        unit.display(barWeight)
    }

    private var targetKg: Double {
        guard let value = Double(targetWeight), value > 0 else { return 0 }
        return unit.toKg(value)
    }

    private var platesPerSide: [Double] {
        let remaining = targetKg - barWeight
        guard remaining > 0 else { return [] }
        var perSide = remaining / 2.0
        var result: [Double] = []
        let plateSizes = availablePlatesKg

        for plate in plateSizes {
            while perSide >= plate - 0.001 {
                result.append(plate)
                perSide -= plate
            }
        }
        return result
    }

    private var actualWeight: Double {
        barWeight + platesPerSide.reduce(0, +) * 2
    }

    private var plateColors: [Double: Color] {
        [
            25: .red,
            20: .blue,
            15: .yellow,
            10: .green,
            5: .white,
            2.5: .red.opacity(0.5),
            1.25: .gray
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Input section
                VStack(spacing: 12) {
                    Text("Target Weight")
                        .font(.headline)

                    HStack {
                        TextField("0", text: $targetWeight)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 200)
                        Text(unit.label)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("Bar:")
                            .foregroundStyle(.secondary)
                        Text(unit.format(barWeight))
                            .font(.subheadline.bold())
                        Stepper("", value: $barWeight, in: 0...50, step: 2.5)
                            .labelsHidden()
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))

                // Bar visualization
                if !platesPerSide.isEmpty {
                    VStack(spacing: 16) {
                        Text("Each Side")
                            .font(.headline)

                        barVisualization
                            .frame(height: 120)

                        // Plate breakdown
                        let grouped = Dictionary(grouping: platesPerSide, by: { $0 })
                        let sorted = grouped.sorted { $0.key > $1.key }

                        VStack(spacing: 8) {
                            ForEach(sorted, id: \.key) { plate, count in
                                HStack {
                                    Circle()
                                        .fill(plateColors[plate] ?? .gray)
                                        .frame(width: 20, height: 20)
                                        .overlay {
                                            Circle().stroke(.primary.opacity(0.3), lineWidth: 1)
                                        }
                                    Text("\(count.count)×")
                                        .font(.headline.monospacedDigit())
                                    Text(unit.format(plate))
                                        .font(.subheadline)
                                    Spacer()
                                    Text("= \(unit.format(plate * Double(count.count) * 2))")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

                        if abs(actualWeight - targetKg) > 0.01 {
                            HStack {
                                Image(systemName: "info.circle")
                                Text("Actual: \(unit.format(actualWeight)) (closest loadable)")
                            }
                            .font(.caption)
                            .foregroundStyle(.orange)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                } else if targetKg > 0 && targetKg <= barWeight {
                    VStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                        Text("Just the bar!")
                            .font(.headline)
                        Text("Target weight is at or below bar weight.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }

                // Quick weight buttons
                VStack(spacing: 12) {
                    Text("Quick Select")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 70))], spacing: 8) {
                        ForEach(quickWeights, id: \.self) { w in
                            Button {
                                targetWeight = String(format: "%.0f", unit.display(w))
                            } label: {
                                Text(unit.formatShort(w))
                                    .font(.subheadline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle("Plate Calculator")
    }

    private var quickWeights: [Double] {
        // in kg
        [40, 60, 80, 100, 120, 140, 160, 180]
    }

    private var barVisualization: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let barWidth = totalWidth * 0.3
            let sideWidth = (totalWidth - barWidth) / 2
            let maxPlateWeight = availablePlatesKg.first ?? 25

            HStack(spacing: 0) {
                // Left plates (mirrored)
                HStack(spacing: 2) {
                    Spacer(minLength: 0)
                    ForEach(Array(platesPerSide.reversed().enumerated()), id: \.offset) { _, plate in
                        let heightRatio = max(0.3, plate / maxPlateWeight)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(plateColors[plate] ?? .gray)
                            .overlay {
                                RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.3), lineWidth: 0.5)
                            }
                            .frame(width: max(8, sideWidth / CGFloat(max(platesPerSide.count, 1)) - 2),
                                   height: geo.size.height * heightRatio)
                    }
                }
                .frame(width: sideWidth)

                // Bar
                RoundedRectangle(cornerRadius: 4)
                    .fill(.gray.opacity(0.6))
                    .frame(width: barWidth, height: 16)

                // Right plates
                HStack(spacing: 2) {
                    ForEach(Array(platesPerSide.enumerated()), id: \.offset) { _, plate in
                        let heightRatio = max(0.3, plate / maxPlateWeight)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(plateColors[plate] ?? .gray)
                            .overlay {
                                RoundedRectangle(cornerRadius: 3).stroke(.primary.opacity(0.3), lineWidth: 0.5)
                            }
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
}

#Preview {
    NavigationStack {
        PlateCalculatorView()
    }
    .environment(\.weightUnit, .kg)
}
