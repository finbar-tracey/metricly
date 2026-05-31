import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(\.appServices) var appServices
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    var workouts: [Workout]
    @Query(sort: \CardioSession.date, order: .reverse) var cardioSessions: [CardioSession]
    @Query var settingsArray: [UserSettings]
    @Query var complianceEvents: [PlanComplianceEvent]
    @State var workoutToDelete: Workout?
    @State var showingOnboarding = false
    /// Workout currently being resumed in the cross-tab pill's sheet. Driven
    /// by the safeAreaInset pill so users can jump back to an open workout
    /// from anywhere in the app.
    @State var resumingWorkout: Workout?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    // iPad
    @State var selectedSidebarItem: SidebarItem? = .home

    // iPhone
    @State var selectedTab: AppTab = .home
    @State var showingSettings = false
    @State var showingSearch = false

    var settings: UserSettings {
        settingsArray.first ?? UserSettings()
    }

    var weightUnit: WeightUnit {
        (settingsArray.first?.useKilograms ?? true) ? .kg : .lbs
    }

    var accentColor: Color {
        (settingsArray.first?.accentColor ?? .blue).color
    }

    var resolvedColorScheme: ColorScheme? {
        AppearanceMode.colorScheme(for: settingsArray.first?.appearanceMode ?? "system")
    }

    /// The most recently created workout that hasn't been finished. Used to
    /// drive the cross-tab "in progress" indicator and the resume action.
    var inProgressWorkout: Workout? {
        workouts.first(where: { !$0.isFinished && !$0.isTemplate })
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        // Thin "Workout in progress" pill at the top — visible on every tab
        // so the user never loses the trail back to an open session. Tap
        // resumes the workout in a sheet (no nav gymnastics across tabs).
        // Below it: the global error banner from AppErrorBus.
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if let active = inProgressWorkout, resumingWorkout?.persistentModelID != active.persistentModelID {
                    ActiveWorkoutPill(workout: active) {
                        resumingWorkout = active
                    }
                }
                ErrorBanner()
            }
        }
        .sheet(item: $resumingWorkout) { workout in
            NavigationStack {
                WorkoutDetailView(workout: workout)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { resumingWorkout = nil }
                        }
                    }
            }
            .environment(\.weightUnit, weightUnit)
        }
        .tint(accentColor)
        .environment(\.weightUnit, weightUnit)
        .environment(\.appServices, AppServices.shared)
        .preferredColorScheme(resolvedColorScheme)
        .fullScreenCover(isPresented: $showingOnboarding) {
            OnboardingView {
                settings.hasSeenOnboarding = true
            }
        }
        .onAppear(perform: performInitialSetup)
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            handleSceneBecameActive()
        }
        .onChange(of: appServices.router.openTrainingTabSignal) { _, _ in
            withAnimation { selectedTab = .training }
        }
        .onChange(of: appServices.router.openInsightsTabSignal) { _, _ in
            withAnimation {
                selectedSidebarItem = .insights
                selectedTab = .training
            }
        }
        .alert("Delete Workout?", isPresented: Binding(
            get: { workoutToDelete != nil },
            set: { if !$0 { workoutToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let workout = workoutToDelete {
                    modelContext.delete(workout)
                    workoutToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { workoutToDelete = nil }
        } message: {
            if let workout = workoutToDelete {
                Text("Are you sure you want to delete \"\(workout.name)\"? This cannot be undone.")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}
