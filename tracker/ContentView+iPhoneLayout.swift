import SwiftUI

extension ContentView {
    var iPhoneLayout: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                homeTab
            }

            Tab("Training", systemImage: "figure.strengthtraining.traditional", value: .training) {
                trainingTab
            }

            Tab("Health", systemImage: "heart.text.square", value: .health) {
                healthTab
            }

            Tab("More", systemImage: "ellipsis.circle", value: .more) {
                moreTab
            }
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
