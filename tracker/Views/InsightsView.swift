import SwiftUI
import SwiftData

enum InsightsTab: String, CaseIterable, Identifiable {
    case volume = "Volume"
    case muscles = "Muscles"
    case bodyWeight = "Weight"
    case recap = "Recap"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .volume: return "chart.bar"
        case .muscles: return "figure.strengthtraining.traditional"
        case .bodyWeight: return "scalemass"
        case .recap: return "list.clipboard"
        }
    }
}

struct InsightsView: View {
    @State private var selectedTab: InsightsTab = .volume
    @Environment(\.weightUnit) private var weightUnit

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $selectedTab) {
                ForEach(InsightsTab.allCases) { tab in
                    Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            switch selectedTab {
            case .volume:
                VolumeChartView()
            case .muscles:
                MuscleGroupSummaryView()
            case .bodyWeight:
                BodyWeightView()
            case .recap:
                WeeklyRecapView()
            }
        }
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
