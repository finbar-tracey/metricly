import SwiftUI
import SwiftData

struct ProgramTemplate: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let author: String
    let difficulty: Difficulty
    let daysPerWeek: Int
    let duration: String
    let category: String
    let workouts: [TemplateWorkout]

    enum Difficulty: String {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"

        var color: Color {
            switch self {
            case .beginner: return .green
            case .intermediate: return .orange
            case .advanced: return .red
            }
        }

        var gradientColors: [Color] {
            switch self {
            case .beginner: return [.green, .teal.opacity(0.7)]
            case .intermediate: return [.orange, .yellow.opacity(0.7)]
            case .advanced: return [.red, .orange.opacity(0.7)]
            }
        }
    }
}

struct TemplateWorkout {
    let name: String
    let exercises: [(name: String, sets: Int, reps: String, group: MuscleGroup)]
}

struct TemplateMarketplaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var existingTemplates: [Workout]
    @State private var selectedTemplate: ProgramTemplate?
    @State private var showingImportConfirm = false
    @State private var importedSuccessfully = false
    @State private var alreadyImported = false
    @State private var selectedCategory = "All"

    private let categories = ["All", "Strength", "Hypertrophy", "Full Body", "Sport"]

    private var filteredTemplates: [ProgramTemplate] {
        selectedCategory == "All" ? Self.templates : Self.templates.filter { $0.category == selectedCategory }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                categoryPickerCard

                ForEach(filteredTemplates) { template in
                    templateCard(template)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Program Templates")
        .alert("Import Program", isPresented: $showingImportConfirm) {
            Button("Import") { if let t = selectedTemplate { importTemplate(t) } }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let t = selectedTemplate {
                Text("Import \"\(t.name)\" as workout templates? This will create \(t.workouts.count) templates.")
            }
        }
        .alert("Imported!", isPresented: $importedSuccessfully) {
            Button("OK") {}
        } message: {
            Text("Templates have been added. You can find them when creating a new workout.")
        }
        .alert("Already Imported", isPresented: $alreadyImported) {
            Button("OK") {}
        } message: {
            Text("All templates from this program have already been imported.")
        }
    }

    // MARK: - Category Picker Card

    private var categoryPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Category", icon: "tag.fill", color: .accentColor)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedCategory = cat }
                        } label: {
                            Text(cat)
                                .font(.caption.bold())
                                .padding(.horizontal, 14).padding(.vertical, 8)
                                .background(selectedCategory == cat ? Color.accentColor : Color(.secondarySystemFill),
                                            in: Capsule())
                                .foregroundStyle(selectedCategory == cat ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .appCard()
    }

    // MARK: - Template Card

    private func templateCard(_ template: ProgramTemplate) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Gradient header
            ZStack(alignment: .bottomLeading) {
                LinearGradient(colors: template.difficulty.gradientColors,
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(.white.opacity(0.07)).frame(width: 140).offset(x: 220, y: -30)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(template.difficulty.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.white.opacity(0.25), in: Capsule())
                            .foregroundStyle(.white)
                        Spacer()
                        Text(template.category)
                            .font(.caption.bold())
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(.white.opacity(0.20), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    Text(template.name)
                        .font(.title3.bold()).foregroundStyle(.white)
                    Text(template.author)
                        .font(.caption).foregroundStyle(.white.opacity(0.75))
                }
                .padding(16)
            }
            .frame(height: 120)

            // Details
            VStack(alignment: .leading, spacing: 14) {
                Text(template.description)
                    .font(.subheadline).foregroundStyle(.secondary).lineLimit(3)

                HStack(spacing: 16) {
                    Label("\(template.daysPerWeek) days/wk", systemImage: "calendar")
                    Label(template.duration, systemImage: "clock")
                }
                .font(.caption).foregroundStyle(.secondary)

                // Workout preview
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(template.workouts.prefix(3), id: \.name) { workout in
                        HStack(spacing: 8) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 10)).foregroundStyle(.accentColor)
                            Text(workout.name).font(.caption.weight(.semibold))
                            Text("· \(workout.exercises.count) exercises")
                                .font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                    if template.workouts.count > 3 {
                        Text("+ \(template.workouts.count - 3) more workouts")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                }
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button {
                    selectedTemplate = template
                    showingImportConfirm = true
                } label: {
                    Label("Import Templates", systemImage: "square.and.arrow.down")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(Color.accentColor.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
        .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
    }

    // MARK: - Import

    private func importTemplate(_ template: ProgramTemplate) {
        let existingNames = Set(existingTemplates.map(\.name))
        let newWorkouts = template.workouts.filter { !existingNames.contains($0.name) }
        if newWorkouts.isEmpty { alreadyImported = true; return }
        for workout in newWorkouts {
            let w = Workout(name: workout.name, isTemplate: true)
            modelContext.insert(w)
            for (index, ex) in workout.exercises.enumerated() {
                let exercise = Exercise(name: ex.name, workout: w, category: ex.group)
                exercise.order = index
                modelContext.insert(exercise)
                w.exercises.append(exercise)
            }
        }
        importedSuccessfully = true
    }

    // MARK: - Template Database

    static let templates: [ProgramTemplate] = [
        ProgramTemplate(name: "Push Pull Legs",
            description: "Classic 6-day split hitting each muscle group twice per week. Great for intermediate lifters looking for balanced hypertrophy.",
            author: "Classic Split", difficulty: .intermediate, daysPerWeek: 6, duration: "Ongoing", category: "Hypertrophy",
            workouts: [
                TemplateWorkout(name: "Push A", exercises: [("Bench Press",4,"6-8",.chest),("Overhead Press",3,"8-10",.shoulders),("Incline Dumbbell Press",3,"10-12",.chest),("Lateral Raise",3,"12-15",.shoulders),("Tricep Pushdown",3,"10-12",.triceps),("Overhead Extension",3,"10-12",.triceps)]),
                TemplateWorkout(name: "Pull A", exercises: [("Barbell Row",4,"6-8",.back),("Lat Pulldown",3,"8-10",.back),("Cable Row",3,"10-12",.back),("Face Pull",3,"15-20",.shoulders),("Barbell Curl",3,"8-10",.biceps),("Hammer Curl",3,"10-12",.biceps)]),
                TemplateWorkout(name: "Legs A", exercises: [("Squat",4,"6-8",.legs),("Romanian Deadlift",3,"8-10",.legs),("Leg Press",3,"10-12",.legs),("Leg Curl",3,"10-12",.legs),("Calf Raise",4,"12-15",.legs)]),
                TemplateWorkout(name: "Push B", exercises: [("Overhead Press",4,"6-8",.shoulders),("Dumbbell Bench Press",3,"8-10",.chest),("Cable Fly",3,"12-15",.chest),("Lateral Raise",4,"12-15",.shoulders),("Skull Crusher",3,"10-12",.triceps)]),
                TemplateWorkout(name: "Pull B", exercises: [("Deadlift",3,"5",.back),("Pull-Up",3,"6-10",.back),("Dumbbell Row",3,"8-10",.back),("Rear Delt Fly",3,"15-20",.shoulders),("Preacher Curl",3,"10-12",.biceps)]),
                TemplateWorkout(name: "Legs B", exercises: [("Front Squat",4,"6-8",.legs),("Bulgarian Split Squat",3,"8-10",.legs),("Leg Extension",3,"12-15",.legs),("Lying Leg Curl",3,"10-12",.legs),("Seated Calf Raise",4,"15-20",.legs)]),
            ]),
        ProgramTemplate(name: "5/3/1 by Wendler",
            description: "Proven strength program built around 4 main lifts with progressive overload using percentages of your training max.",
            author: "Jim Wendler", difficulty: .intermediate, daysPerWeek: 4, duration: "4-week cycles", category: "Strength",
            workouts: [
                TemplateWorkout(name: "5/3/1 Squat", exercises: [("Squat",3,"5/3/1",.legs),("Leg Press",3,"10-12",.legs),("Leg Curl",3,"10-12",.legs),("Ab Wheel",3,"10-15",.core)]),
                TemplateWorkout(name: "5/3/1 Bench", exercises: [("Bench Press",3,"5/3/1",.chest),("Dumbbell Bench Press",3,"10-12",.chest),("Dumbbell Row",3,"10-12",.back),("Tricep Pushdown",3,"10-12",.triceps)]),
                TemplateWorkout(name: "5/3/1 Deadlift", exercises: [("Deadlift",3,"5/3/1",.back),("Good Morning",3,"10-12",.legs),("Hanging Leg Raise",3,"10-15",.core)]),
                TemplateWorkout(name: "5/3/1 OHP", exercises: [("Overhead Press",3,"5/3/1",.shoulders),("Chin-Up",3,"8-10",.back),("Lateral Raise",3,"12-15",.shoulders),("Face Pull",3,"15-20",.shoulders)]),
            ]),
        ProgramTemplate(name: "Starting Strength",
            description: "The gold standard beginner linear progression program. Simple, effective, built around compound movements.",
            author: "Mark Rippetoe", difficulty: .beginner, daysPerWeek: 3, duration: "3-6 months", category: "Strength",
            workouts: [
                TemplateWorkout(name: "SS Workout A", exercises: [("Squat",3,"5",.legs),("Bench Press",3,"5",.chest),("Deadlift",1,"5",.back)]),
                TemplateWorkout(name: "SS Workout B", exercises: [("Squat",3,"5",.legs),("Overhead Press",3,"5",.shoulders),("Barbell Row",3,"5",.back)]),
            ]),
        ProgramTemplate(name: "GZCLP",
            description: "Beginner-friendly linear progression with tiered exercise structure. Great balance of strength and hypertrophy.",
            author: "Cody LeFever", difficulty: .beginner, daysPerWeek: 4, duration: "3-6 months", category: "Strength",
            workouts: [
                TemplateWorkout(name: "GZCLP Day 1", exercises: [("Squat",5,"3",.legs),("Bench Press",3,"10",.chest),("Lat Pulldown",3,"15",.back)]),
                TemplateWorkout(name: "GZCLP Day 2", exercises: [("Overhead Press",5,"3",.shoulders),("Deadlift",3,"10",.back),("Dumbbell Row",3,"15",.back)]),
                TemplateWorkout(name: "GZCLP Day 3", exercises: [("Bench Press",5,"3",.chest),("Squat",3,"10",.legs),("Lat Pulldown",3,"15",.back)]),
                TemplateWorkout(name: "GZCLP Day 4", exercises: [("Deadlift",5,"3",.back),("Overhead Press",3,"10",.shoulders),("Dumbbell Row",3,"15",.back)]),
            ]),
        ProgramTemplate(name: "Upper Lower Split",
            description: "4-day program alternating upper and lower body. Solid frequency and recovery balance for all levels.",
            author: "Classic Split", difficulty: .beginner, daysPerWeek: 4, duration: "Ongoing", category: "Full Body",
            workouts: [
                TemplateWorkout(name: "Upper A", exercises: [("Bench Press",4,"6-8",.chest),("Barbell Row",4,"6-8",.back),("Overhead Press",3,"8-10",.shoulders),("Barbell Curl",3,"10-12",.biceps),("Tricep Pushdown",3,"10-12",.triceps)]),
                TemplateWorkout(name: "Lower A", exercises: [("Squat",4,"6-8",.legs),("Romanian Deadlift",3,"8-10",.legs),("Leg Press",3,"10-12",.legs),("Leg Curl",3,"10-12",.legs),("Calf Raise",4,"12-15",.legs)]),
                TemplateWorkout(name: "Upper B", exercises: [("Dumbbell Bench Press",3,"8-10",.chest),("Pull-Up",3,"6-10",.back),("Dumbbell Shoulder Press",3,"10-12",.shoulders),("Hammer Curl",3,"10-12",.biceps),("Overhead Extension",3,"10-12",.triceps)]),
                TemplateWorkout(name: "Lower B", exercises: [("Deadlift",3,"5",.back),("Front Squat",3,"8-10",.legs),("Bulgarian Split Squat",3,"10-12",.legs),("Leg Extension",3,"12-15",.legs),("Seated Calf Raise",4,"15-20",.legs)]),
            ]),
    ]
}

#Preview {
    NavigationStack { TemplateMarketplaceView() }
        .modelContainer(for: Workout.self, inMemory: true)
}
