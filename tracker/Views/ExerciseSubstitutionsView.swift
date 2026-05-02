import SwiftUI

struct SubstitutionDestination: Hashable {
    let exerciseName: String
}

struct ExerciseSubstitutionsView: View {
    let exerciseName: String

    private var substitutions: [SubstitutionGroup] {
        let name = exerciseName.lowercased()
        var matches: [SubstitutionGroup] = []
        for group in Self.substitutionDatabase {
            let exerciseNames = group.exercises.map { $0.lowercased() }
            if exerciseNames.contains(where: { name.contains($0) || $0.contains(name) }) {
                matches.append(group)
            }
        }
        if matches.isEmpty {
            for group in Self.substitutionDatabase {
                if name.contains(group.muscleGroup.lowercased()) { matches.append(group) }
            }
        }
        return matches
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if substitutions.isEmpty {
                    emptyStateCard
                } else {
                    ForEach(substitutions) { group in
                        groupCard(group)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Substitutions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Group Card

    private func groupCard(_ group: SubstitutionGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: group.muscleGroup, icon: group.icon, color: .accentColor)

            VStack(spacing: 0) {
                ForEach(Array(group.exercises
                    .filter { $0.lowercased() != exerciseName.lowercased() }
                    .enumerated()), id: \.offset) { idx, exercise in
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 32, height: 32)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.accentColor)
                        }
                        Text(exercise).font(.subheadline.weight(.medium))
                        Spacer()
                    }
                    .padding(.horizontal, 16).padding(.vertical, 11)

                    if idx < group.exercises.filter({ $0.lowercased() != exerciseName.lowercased() }).count - 1 {
                        Divider().padding(.leading, 60)
                    }
                }
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            if !group.notes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.caption).foregroundStyle(.secondary)
                    Text(group.notes).font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
        }
        .appCard()
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("No Substitutions Found").font(.headline)
                Text("Try exercises with common names like Bench Press, Squat, or Deadlift.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }

    // MARK: - Substitution Database

    static let substitutionDatabase: [SubstitutionGroup] = [
        SubstitutionGroup(muscleGroup: "Chest - Press", icon: "figure.strengthtraining.traditional",
            exercises: ["Bench Press", "Dumbbell Bench Press", "Incline Bench Press", "Incline Dumbbell Press", "Machine Chest Press", "Floor Press", "Push-Up"],
            notes: "These target the chest with pressing movements. Incline variations emphasize upper chest."),
        SubstitutionGroup(muscleGroup: "Chest - Fly", icon: "figure.strengthtraining.traditional",
            exercises: ["Cable Fly", "Dumbbell Fly", "Pec Deck", "Machine Fly", "Incline Dumbbell Fly"],
            notes: "Isolation movements for chest. Lower weight, focus on stretch and squeeze."),
        SubstitutionGroup(muscleGroup: "Back - Row", icon: "figure.rowing",
            exercises: ["Barbell Row", "Dumbbell Row", "Cable Row", "T-Bar Row", "Machine Row", "Pendlay Row", "Chest Supported Row"],
            notes: "Horizontal pulling for back thickness. Chest supported rows reduce lower back stress."),
        SubstitutionGroup(muscleGroup: "Back - Pulldown", icon: "figure.rowing",
            exercises: ["Lat Pulldown", "Pull-Up", "Chin-Up", "Wide Grip Pulldown", "Close Grip Pulldown", "Assisted Pull-Up"],
            notes: "Vertical pulling for lat width. Chin-ups add more bicep involvement."),
        SubstitutionGroup(muscleGroup: "Shoulders - Press", icon: "figure.arms.open",
            exercises: ["Overhead Press", "Dumbbell Shoulder Press", "Arnold Press", "Machine Shoulder Press", "Landmine Press", "Push Press"],
            notes: "Overhead pressing for shoulder development. Seated removes leg drive."),
        SubstitutionGroup(muscleGroup: "Shoulders - Lateral", icon: "figure.arms.open",
            exercises: ["Lateral Raise", "Cable Lateral Raise", "Machine Lateral Raise", "Dumbbell Lateral Raise", "Upright Row"],
            notes: "Side delt isolation. Keep weights lighter and control the movement."),
        SubstitutionGroup(muscleGroup: "Legs - Quad", icon: "figure.walk",
            exercises: ["Squat", "Front Squat", "Leg Press", "Hack Squat", "Goblet Squat", "Bulgarian Split Squat", "Leg Extension", "Lunges"],
            notes: "Quad-dominant leg movements. Split squats are great unilateral alternatives."),
        SubstitutionGroup(muscleGroup: "Legs - Hamstring", icon: "figure.walk",
            exercises: ["Romanian Deadlift", "Leg Curl", "Lying Leg Curl", "Nordic Curl", "Good Morning", "Stiff Leg Deadlift", "Seated Leg Curl"],
            notes: "Hamstring-focused exercises. RDLs also train the glutes heavily."),
        SubstitutionGroup(muscleGroup: "Legs - Compound", icon: "figure.walk",
            exercises: ["Deadlift", "Sumo Deadlift", "Trap Bar Deadlift", "Hip Thrust", "Barbell Squat", "Leg Press"],
            notes: "Heavy compound leg movements. Trap bar deadlift is easier on the lower back."),
        SubstitutionGroup(muscleGroup: "Biceps", icon: "figure.strengthtraining.functional",
            exercises: ["Barbell Curl", "Dumbbell Curl", "Hammer Curl", "Preacher Curl", "Cable Curl", "Incline Curl", "EZ Bar Curl", "Concentration Curl"],
            notes: "Bicep isolation work. Hammer curls also hit the brachialis."),
        SubstitutionGroup(muscleGroup: "Triceps", icon: "figure.strengthtraining.functional",
            exercises: ["Tricep Pushdown", "Overhead Tricep Extension", "Skull Crusher", "Close Grip Bench Press", "Dips", "Cable Kickback", "Diamond Push-Up"],
            notes: "Tricep isolation and compound exercises. Overhead work stretches the long head."),
        SubstitutionGroup(muscleGroup: "Core", icon: "figure.core.training",
            exercises: ["Plank", "Cable Crunch", "Hanging Leg Raise", "Ab Wheel Rollout", "Russian Twist", "Decline Sit-Up", "Dead Bug", "Pallof Press"],
            notes: "Core stability and anti-rotation exercises. Pallof press is excellent for functional core strength."),
    ]
}

struct SubstitutionGroup: Identifiable {
    let id = UUID()
    let muscleGroup: String
    let icon: String
    let exercises: [String]
    let notes: String
}

#Preview {
    NavigationStack { ExerciseSubstitutionsView(exerciseName: "Bench Press") }
}
