import SwiftUI
import SwiftData

enum InsightsTab: String, CaseIterable, Identifiable {
    case volume = "Volume"
    case muscles = "Muscles"
    case recovery = "Recovery"
    case bodyWeight = "Weight"
    case recap = "Report"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .volume: return "chart.bar"
        case .muscles: return "figure.strengthtraining.traditional"
        case .recovery: return "heart.text.square"
        case .bodyWeight: return "scalemass"
        case .recap: return "doc.text.magnifyingglass"
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
                    Image(systemName: tab.icon).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 8)

            // Show selected tab name
            Text(selectedTab.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 6)

            switch selectedTab {
            case .volume:
                VolumeTrendsView()
            case .muscles:
                MuscleGroupSummaryView()
            case .recovery:
                MuscleRecoveryView()
            case .bodyWeight:
                BodyWeightView()
            case .recap:
                WeeklyMonthlyReportView()
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
