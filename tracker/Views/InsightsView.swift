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
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(InsightsTab.allCases) { tab in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12, weight: .semibold))
                                Text(tab.rawValue)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                selectedTab == tab
                                    ? AnyShapeStyle(Color.accentColor)
                                    : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                                in: Capsule()
                            )
                            .foregroundStyle(selectedTab == tab ? .white : .secondary)
                            .shadow(
                                color: selectedTab == tab ? Color.accentColor.opacity(0.35) : .clear,
                                radius: 6, x: 0, y: 3
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }

            Group {
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
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.2), value: selectedTab)
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
