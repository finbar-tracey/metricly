import SwiftUI

struct PlateCalculatorView: View {
    @Environment(\.weightUnit) private var unit
    @State private var targetWeight: String = ""
    @State private var barWeight: Double = 20.0

    private var targetKg: Double {
        PlateCalculatorEngine.targetKg(displayValue: targetWeight, unit: unit)
    }

    private var platesPerSide: [Double] {
        PlateCalculatorEngine.platesPerSide(targetKg: targetKg, barWeightKg: barWeight)
    }

    private var actualWeight: Double {
        PlateCalculatorEngine.actualWeightKg(barWeightKg: barWeight, platesPerSide: platesPerSide)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                PlateCalculatorSections.inputHeroCard(
                    unit: unit,
                    targetWeight: $targetWeight,
                    barWeight: $barWeight
                )

                if !platesPerSide.isEmpty {
                    PlateCalculatorSections.plateResultCard(
                        unit: unit,
                        platesPerSide: platesPerSide,
                        targetKg: targetKg,
                        actualWeightKg: actualWeight
                    )
                } else if targetKg > 0 && targetKg <= barWeight {
                    PlateCalculatorSections.justTheBarCard()
                }

                PlateCalculatorSections.quickSelectCard(unit: unit) { w in
                    targetWeight = String(format: "%.0f", unit.display(w))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Plate Calculator")
    }
}

#Preview {
    NavigationStack { PlateCalculatorView() }
        .environment(\.weightUnit, .kg)
}
