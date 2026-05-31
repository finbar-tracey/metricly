import SwiftUI

/// Shared scroll shell for health metric detail screens.
struct MetricDetailScaffold<Hero: View, Content: View>: View {
    let navigationTitle: String
    let isLoading: Bool
    let isEmpty: Bool
    let loadingMessage: String
    let emptyIcon: String
    let emptyTitle: String
    let emptySubtitle: String
    @Binding var timeRange: DetailTimeRange
    let segmentColor: Color
    let showRangePicker: Bool
    @ViewBuilder let hero: () -> Hero
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isLoading && isEmpty {
                    LoadingStateView(loadingMessage)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if isEmpty && !isLoading {
                    EmptyStateView(icon: emptyIcon, title: emptyTitle, subtitle: emptySubtitle)
                        .padding(.top, 60)
                } else {
                    hero()
                    if showRangePicker {
                        HStack {
                            CapsuleSegmentPicker(
                                options: DetailTimeRange.allCases,
                                selection: $timeRange,
                                activeColor: segmentColor
                            )
                            Spacer()
                        }
                    }
                    content()
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
