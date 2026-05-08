import SwiftUI
import SwiftData

enum InsightsTab: String, CaseIterable, Identifiable {
    case patterns = "Patterns"
    case volume = "Volume"
    case muscles = "Muscles"
    case recovery = "Recovery"
    case bodyWeight = "Weight"
    case recap = "Report"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .patterns: return "sparkles"
        case .volume: return "chart.bar"
        case .muscles: return "figure.strengthtraining.traditional"
        case .recovery: return "heart.text.square"
        case .bodyWeight: return "scalemass"
        case .recap: return "doc.text.magnifyingglass"
        }
    }

    var tint: Color {
        switch self {
        case .patterns: return .indigo
        case .volume: return .green
        case .muscles: return .purple
        case .recovery: return .red
        case .bodyWeight: return .blue
        case .recap: return .orange
        }
    }
}

struct InsightsView: View {
    @State private var selectedTab: InsightsTab = .patterns
    @Environment(\.weightUnit) private var weightUnit

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(InsightsTab.allCases) { tab in
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                                selectedTab = tab
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 12, weight: .bold))
                                Text(tab.rawValue)
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [tab.tint, tab.tint.opacity(0.72)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .shadow(color: tab.tint.opacity(0.45), radius: 8, x: 0, y: 4)
                                } else {
                                    Capsule().fill(Color(.secondarySystemGroupedBackground))
                                }
                            }
                            .foregroundStyle(selectedTab == tab ? .white : .primary)
                        }
                        .buttonStyle(.pressableCard)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
            }

            Group {
                switch selectedTab {
                case .patterns:
                    PersonalInsightsView()
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
