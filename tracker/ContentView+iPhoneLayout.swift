import SwiftUI

extension ContentView {
    var iPhoneLayout: some View {
        // The system tab bar is hidden per-tab rather than on the TabView —
        // that's where `toolbarVisibility(_:for: .tabBar)` actually takes
        // effect. `MetriclyTabBar` replaces it as a bottom safe-area inset, so
        // scroll content still insets correctly underneath it.
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                homeTab
                    .toolbarVisibility(.hidden, for: .tabBar)
            }

            Tab("Training", systemImage: "figure.strengthtraining.traditional", value: .training) {
                trainingTab
                    .toolbarVisibility(.hidden, for: .tabBar)
            }

            Tab("Health", systemImage: "heart.text.square", value: .health) {
                healthTab
                    .toolbarVisibility(.hidden, for: .tabBar)
            }

            Tab("More", systemImage: "ellipsis.circle", value: .more) {
                moreTab
                    .toolbarVisibility(.hidden, for: .tabBar)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !tabBarHidden {
                MetriclyTabBar(selection: $selectedTab, accent: accentColor)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onMetriclyTabBarHiddenChange { hidden in
            withAnimation(.snappy(duration: 0.25)) { tabBarHidden = hidden }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSettings = false }
                        }
                    }
            }
        }
    }
}
