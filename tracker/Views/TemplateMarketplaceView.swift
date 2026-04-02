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
    }
}

struct TemplateWorkout {
    let name: String
    let exercises: [(name: String, sets: Int, reps: String, group: MuscleGroup)]
}

struct TemplateMarketplaceView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTemplate: ProgramTemplate?
    @State private var showingImportConfirm = false
    @State private var importedSuccessfully = false
    @State private var selectedCategory = "All"

    private let categories = ["All", "Strength", "Hypertrophy", "Full Body", "Sport"]

    private var filteredTemplates: [ProgramTemplate] {
        if selectedCategory == "All" { return Self.templates }
        return Self.templates.filter { $0.category == selectedCategory }
    }

    var body: some View {
        List {
            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { cat in
                        Button {
                            selectedCategory = cat
                        } label: {
                            Text(cat)
                                .font(.subheadline.weight(selectedCategory == cat ? .bold : .regular))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(selectedCategory == cat ? Color.accentColor : Color(.secondarySystemFill),
                                            in: Capsule())
                                .foregroundStyle(selectedCategory == cat ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            .listRowBackground(Color.clear)

            ForEach(filteredTemplates) { template in
                templateCard(template)
            }
        }
        .navigationTitle("Program Templates")
        .alert("Import Program", isPresented: $showingImportConfirm) {
            Button("Import") {
                if let template = selectedTemplate {
                    importTemplate(template)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let template = selectedTemplate {
                Text("Import \"\(template.name)\" as workout templates? This will create \(template.workouts.count) templates you can use when starting workouts.")
            }
        }
        .alert("Imported!", isPresented: $importedSuccessfully) {
            Button("OK") {}
        } message: {
            Text("Templates have been added. You can find them when creating a new workout.")
        }
    }

    private func templateCard(_ template: ProgramTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.author)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(template.difficulty.rawValue)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(template.difficulty.color.opacity(0.2), in: Capsule())
                    .foregroundStyle(template.difficulty.color)
            }

            Text(template.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label("\(template.daysPerWeek) days/wk", systemImage: "calendar")
                Label(template.duration, systemImage: "clock")
                Label(template.category, systemImage: "tag")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Workout preview
            VStack(alignment: .leading, spacing: 4) {
                ForEach(template.workouts.prefix(3), id: \.name) { workout in
                    HStack {
                        Text(workout.name)
                            .font(.caption.bold())
                        Text("· \(workout.exercises.count) exercises")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if template.workouts.count > 3 {
                    Text("+\(template.workouts.count - 3) more")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 8))

            Button {
                selectedTemplate = template
                showingImportConfirm = true
            } label: {
                Text("Import Templates")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func importTemplate(_ template: ProgramTemplate) {
        for workout in template.workouts {
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
        ProgramTemplate(
            name: "Push Pull Legs",
            description: "Classic 6-day split hitting each muscle group twice per week. Great for intermediate lifters looking for balanced hypertrophy.",
            author: "Classic Split", difficulty: .intermediate, daysPerWeek: 6, duration: "Ongoing", category: "Hypertrophy",
            workouts: [
                TemplateWorkout(name: "Push A", exercises: [
                    ("Bench Press", 4, "6-8", .chest), ("Overhead Press", 3, "8-10", .shoulders),
                    ("Incline Dumbbell Press", 3, "10-12", .chest), ("Lateral Raise", 3, "12-15", .shoulders),
                    ("Tricep Pushdown", 3, "10-12", .triceps), ("Overhead Extension", 3, "10-12", .triceps)
                ]),
                TemplateWorkout(name: "Pull A", exercises: [
                    ("Barbell Row", 4, "6-8", .back), ("Lat Pulldown", 3, "8-10", .back),
                    ("Cable Row", 3, "10-12", .back), ("Face Pull", 3, "15-20", .shoulders),
                    ("Barbell Curl", 3, "8-10", .biceps), ("Hammer Curl", 3, "10-12", .biceps)
                ]),
                TemplateWorkout(name: "Legs A", exercises: [
                    ("Squat", 4, "6-8", .legs), ("Romanian Deadlift", 3, "8-10", .legs),
                    ("Leg Press", 3, "10-12", .legs), ("Leg Curl", 3, "10-12", .legs),
                    ("Calf Raise", 4, "12-15", .legs)
                ]),
                TemplateWorkout(name: "Push B", exercises: [
                    ("Overhead Press", 4, "6-8", .shoulders), ("Dumbbell Bench Press", 3, "8-10", .chest),
                    ("Cable Fly", 3, "12-15", .chest), ("Lateral Raise", 4, "12-15", .shoulders),
                    ("Skull Crusher", 3, "10-12", .triceps)
                ]),
                TemplateWorkout(name: "Pull B", exercises: [
                    ("Deadlift", 3, "5", .back), ("Pull-Up", 3, "6-10", .back),
                    ("Dumbbell Row", 3, "8-10", .back), ("Rear Delt Fly", 3, "15-20", .shoulders),
                    ("Preacher Curl", 3, "10-12", .biceps)
                ]),
                TemplateWorkout(name: "Legs B", exercises: [
                    ("Front Squat", 4, "6-8", .legs), ("Bulgarian Split Squat", 3, "8-10", .legs),
                    ("Leg Extension", 3, "12-15", .legs), ("Lying Leg Curl", 3, "10-12", .legs),
                    ("Seated Calf Raise", 4, "15-20", .legs)
                ]),
            ]
        ),
        ProgramTemplate(
            name: "5/3/1 by Wendler",
            description: "Proven strength program built around 4 main lifts with progressive overload using percentages of your training max.",
            author: "Jim Wendler", difficulty: .intermediate, daysPerWeek: 4, duration: "4-week cycles", category: "Strength",
            workouts: [
                TemplateWorkout(name: "5/3/1 Squat", exercises: [
                    ("Squat", 3, "5/3/1", .legs), ("Leg Press", 3, "10-12", .legs),
                    ("Leg Curl", 3, "10-12", .legs), ("Ab Wheel", 3, "10-15", .core)
                ]),
                TemplateWorkout(name: "5/3/1 Bench", exercises: [
                    ("Bench Press", 3, "5/3/1", .chest), ("Dumbbell Bench Press", 3, "10-12", .chest),
                    ("Dumbbell Row", 3, "10-12", .back), ("Tricep Pushdown", 3, "10-12", .triceps)
                ]),
                TemplateWorkout(name: "5/3/1 Deadlift", exercises: [
                    ("Deadlift", 3, "5/3/1", .back), ("Good Morning", 3, "10-12", .legs),
                    ("Hanging Leg Raise", 3, "10-15", .core)
                ]),
                TemplateWorkout(name: "5/3/1 OHP", exercises: [
                    ("Overhead Press", 3, "5/3/1", .shoulders), ("Chin-Up", 3, "8-10", .back),
                    ("Lateral Raise", 3, "12-15", .shoulders), ("Face Pull", 3, "15-20", .shoulders)
                ]),
            ]
        ),
        ProgramTemplate(
            name: "Starting Strength",
            description: "The gold standard beginner linear progression program. Simple, effective, built around compound movements.",
            author: "Mark Rippetoe", difficulty: .beginner, daysPerWeek: 3, duration: "3-6 months", category: "Strength",
            workouts: [
                TemplateWorkout(name: "SS Workout A", exercises: [
                    ("Squat", 3, "5", .legs), ("Bench Press", 3, "5", .chest),
                    ("Deadlift", 1, "5", .back)
                ]),
                TemplateWorkout(name: "SS Workout B", exercises: [
                    ("Squat", 3, "5", .legs), ("Overhead Press", 3, "5", .shoulders),
                    ("Barbell Row", 3, "5", .back)
                ]),
            ]
        ),
        ProgramTemplate(
            name: "GZCLP",
            description: "Beginner-friendly linear progression with tiered exercise structure. Great balance of strength and hypertrophy.",
            author: "Cody LeFever", difficulty: .beginner, daysPerWeek: 4, duration: "3-6 months", category: "Strength",
            workouts: [
                TemplateWorkout(name: "GZCLP Day 1", exercises: [
                    ("Squat", 5, "3", .legs), ("Bench Press", 3, "10", .chest),
                    ("Lat Pulldown", 3, "15", .back)
                ]),
                TemplateWorkout(name: "GZCLP Day 2", exercises: [
                    ("Overhead Press", 5, "3", .shoulders), ("Deadlift", 3, "10", .back),
                    ("Dumbbell Row", 3, "15", .back)
                ]),
                TemplateWorkout(name: "GZCLP Day 3", exercises: [
                    ("Bench Press", 5, "3", .chest), ("Squat", 3, "10", .legs),
                    ("Lat Pulldown", 3, "15", .back)
                ]),
                TemplateWorkout(name: "GZCLP Day 4", exercises: [
                    ("Deadlift", 5, "3", .back), ("Overhead Press", 3, "10", .shoulders),
                    ("Dumbbell Row", 3, "15", .back)
                ]),
            ]
        ),
        ProgramTemplate(
            name: "Upper Lower Split",
            description: "4-day program alternating upper and lower body. Solid frequency and recovery balance for all levels.",
            author: "Classic Split", difficulty: .beginner, daysPerWeek: 4, duration: "Ongoing", category: "Full Body",
            workouts: [
                TemplateWorkout(name: "Upper A", exercises: [
                    ("Bench Press", 4, "6-8", .chest), ("Barbell Row", 4, "6-8", .back),
                    ("Overhead Press", 3, "8-10", .shoulders), ("Barbell Curl", 3, "10-12", .biceps),
                    ("Tricep Pushdown", 3, "10-12", .triceps)
                ]),
                TemplateWorkout(name: "Lower A", exercises: [
                    ("Squat", 4, "6-8", .legs), ("Romanian Deadlift", 3, "8-10", .legs),
                    ("Leg Press", 3, "10-12", .legs), ("Leg Curl", 3, "10-12", .legs),
                    ("Calf Raise", 4, "12-15", .legs)
                ]),
                TemplateWorkout(name: "Upper B", exercises: [
                    ("Dumbbell Bench Press", 3, "8-10", .chest), ("Pull-Up", 3, "6-10", .back),
                    ("Dumbbell Shoulder Press", 3, "10-12", .shoulders), ("Hammer Curl", 3, "10-12", .biceps),
                    ("Overhead Extension", 3, "10-12", .triceps)
                ]),
                TemplateWorkout(name: "Lower B", exercises: [
                    ("Deadlift", 3, "5", .back), ("Front Squat", 3, "8-10", .legs),
                    ("Bulgarian Split Squat", 3, "10-12", .legs), ("Leg Extension", 3, "12-15", .legs),
                    ("Seated Calf Raise", 4, "15-20", .legs)
                ]),
            ]
        ),
    ]
}

#Preview {
    NavigationStack {
        TemplateMarketplaceView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
