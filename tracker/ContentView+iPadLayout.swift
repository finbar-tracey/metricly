import SwiftUI

extension ContentView {
    var iPadLayout: some View {
        NavigationSplitView {
            List(selection: $selectedSidebarItem) {
                Section {
                    Label("Home", systemImage: "house").tag(SidebarItem.home)
                }
                Section("Track") {
                    Label("Workouts",     systemImage: "dumbbell")                  .tag(SidebarItem.workouts)
                    Label("Programs",     systemImage: "calendar.badge.clock")      .tag(SidebarItem.programs)
                    Label("Schedule",     systemImage: "calendar.badge.checkmark")  .tag(SidebarItem.schedule)
                    Label("Calendar",     systemImage: "calendar")                  .tag(SidebarItem.calendar)
                    Label("Cardio",       systemImage: "figure.run")                .tag(SidebarItem.cardio)
                    Label("Activity Log", systemImage: "list.bullet.rectangle")     .tag(SidebarItem.activityLog)
                }
                Section("Progress") {
                    Label("Achievements",      systemImage: "medal")               .tag(SidebarItem.achievements)
                    Label("Streak",            systemImage: "flame")               .tag(SidebarItem.streak)
                    Label("Personal Records",  systemImage: "trophy")              .tag(SidebarItem.personalRecords)
                    Label("Progress Photos",   systemImage: "camera")              .tag(SidebarItem.progressPhotos)
                    Label("Measurements",      systemImage: "ruler")               .tag(SidebarItem.measurements)
                    Label("Body Weight",       systemImage: "scalemass")           .tag(SidebarItem.bodyWeight)
                    Label("Body Fat %",        systemImage: "percent")             .tag(SidebarItem.bodyFat)
                    Label("Lift Goals",        systemImage: "target")              .tag(SidebarItem.liftGoals)
                }
                Section("Health") {
                    Label("Health Dashboard",  systemImage: "heart.text.square")   .tag(SidebarItem.health)
                    Label("Water",             systemImage: "drop.fill")           .tag(SidebarItem.water)
                    Label("Caffeine",          systemImage: "cup.and.saucer.fill") .tag(SidebarItem.caffeine)
                    Label("Creatine",          systemImage: "pill.fill")           .tag(SidebarItem.creatine)
                }
                Section("Analyze") {
                    Label("Insights",          systemImage: "chart.bar")               .tag(SidebarItem.insights)
                    Label("Exercise Library",  systemImage: "books.vertical")          .tag(SidebarItem.exerciseLibrary)
                    Label("Compare Workouts",  systemImage: "arrow.left.arrow.right")  .tag(SidebarItem.comparison)
                    Label("Smart Suggestions", systemImage: "lightbulb")               .tag(SidebarItem.smartSuggestions)
                }
                Section("Tools") {
                    Label("Plate Calculator",  systemImage: "circle.grid.cross") .tag(SidebarItem.plateCalculator)
                    Label("1RM Calculator",    systemImage: "function")          .tag(SidebarItem.oneRepMax)
                    Label("Workout Timers",    systemImage: "timer")             .tag(SidebarItem.workoutTimers)
                }
                Section {
                    Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
                }
            }
            .navigationTitle("Metricly")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingSearch = true } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search")
                }
            }
            .sheet(isPresented: $showingSearch) { GlobalSearchView() }
        } detail: {
            NavigationStack {
                sidebarDetailContent
            }
            .navigationDestination(for: Workout.self) { workout in WorkoutDetailView(workout: workout) }
            .navigationDestination(for: String.self)  { name in ExerciseHistoryView(exerciseName: name) }
        }
        .navigationSplitViewStyle(.balanced)
    }
}
