import SwiftUI

struct HealthHubView: View {
    var body: some View {
        List {
            Section("Health") {
                NavigationLink { HealthDashboardView() } label: {
                    hubRow(icon: "heart.text.square", color: .red, title: "Health Dashboard", subtitle: "Steps, heart rate, sleep & more")
                }
                NavigationLink { CaffeineTrackerView() } label: {
                    hubRow(icon: "cup.and.saucer.fill", color: .brown, title: "Caffeine Tracker", subtitle: "Half-life decay & sleep readiness")
                }
                NavigationLink { WaterTrackerView() } label: {
                    hubRow(icon: "drop.fill", color: .cyan, title: "Water Tracker", subtitle: "Daily hydration tracking")
                }
                NavigationLink { CreatineTrackerView() } label: {
                    hubRow(icon: "pill.fill", color: .blue, title: "Creatine Tracker", subtitle: "Daily supplement tracking")
                }
            }

            Section("Body") {
                NavigationLink { BodyWeightView() } label: {
                    hubRow(icon: "scalemass", color: .blue, title: "Body Weight", subtitle: "Weigh-ins & trend line")
                }
                NavigationLink { BodyMeasurementsView() } label: {
                    hubRow(icon: "ruler", color: .teal, title: "Measurements", subtitle: "Body circumference tracking")
                }
                NavigationLink { BodyFatEstimateView() } label: {
                    hubRow(icon: "percent", color: .indigo, title: "Body Fat %", subtitle: "Navy method estimation")
                }
                NavigationLink { ProgressPhotosView() } label: {
                    hubRow(icon: "camera", color: .blue, title: "Progress Photos", subtitle: "Visual transformation")
                }
            }
        }
        .navigationTitle("Health")
    }
}
