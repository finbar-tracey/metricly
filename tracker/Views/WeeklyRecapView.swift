import SwiftUI
import SwiftData

struct WeeklyRecapView: View {
    @Query(filter: #Predicate<Workout> { !$0.isTemplate }, sort: \Workout.date, order: .reverse)
    private var allWorkouts: [Workout]
    @Environment(\.weightUnit) private var weightUnit

    private var lastWeekRange: (start: Date, end: Date) {
        let calendar = Calendar.current
        let now = Date.now
        guard let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start else {
            return (now, now)
        }
        let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: thisWeekStart)!
        return (lastWeekStart, thisWeekStart)
    }

    private var lastWeekWorkouts: [Workout] {
        let range = lastWeekRange
        return allWorkouts.filter { $0.date >= range.start && $0.date < range.end }
    }

    private var previousWorkouts: [Workout] {
        let range = lastWeekRange
        return allWorkouts.filter { $0.date < range.start }
    }

    // Total workouts last week
    private var workoutCount: Int {
        lastWeekWorkouts.count
    }

    // Total sets last week
    private var totalSets: Int {
        lastWeekWorkouts.reduce(0) { total, workout in
            total + workout.exercises.reduce(0) { $0 + $1.sets.filter { !$0.isWarmUp }.count }
        }
    }

    // Total volume last week
    private var totalVolume: Double {
        let volumeKg = lastWeekWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
        return weightUnit == .kg ? volumeKg : volumeKg * 2.20462
    }

    // Total duration last week
    private var totalDuration: TimeInterval {
        lastWeekWorkouts.reduce(0) { total, workout in
            total + (workout.duration ?? 0)
        }
    }

    private var formattedDuration: String {
        let totalMinutes = Int(totalDuration) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    // Average rating last week
    private var averageRating: Double? {
        let ratings = lastWeekWorkouts.compactMap(\.rating).filter { $0 > 0 }
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }

    // PRs hit last week: compare each exercise's max weight vs historical max
    private var prsHit: Int {
        // Build historical max per exercise name from workouts BEFORE last week
        var historicalMax: [String: Double] = [:]
        for workout in previousWorkouts {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                let key = exercise.name.lowercased()
                historicalMax[key] = Swift.max(historicalMax[key] ?? 0, maxWeight)
            }
        }

        // Count exercises from last week that exceeded historical max
        var prCount = 0
        for workout in lastWeekWorkouts {
            for exercise in workout.exercises {
                let maxWeight = exercise.sets.filter { !$0.isWarmUp }.map(\.weight).max() ?? 0
                let key = exercise.name.lowercased()
                if maxWeight > 0, maxWeight > (historicalMax[key] ?? 0) {
                    prCount += 1
                    // Update historical max so we don't double count within the week
                    historicalMax[key] = maxWeight
                }
            }
        }
        return prCount
    }

    // Muscle groups trained last week
    private var muscleGroupsHit: [MuscleGroup] {
        var groups = Set<MuscleGroup>()
        for workout in lastWeekWorkouts {
            for exercise in workout.exercises {
                if let category = exercise.category {
                    groups.insert(category)
                }
            }
        }
        return Array(groups).sorted { $0.rawValue < $1.rawValue }
    }

    // Comparison to the week before last
    private var twoWeeksAgoRange: (start: Date, end: Date) {
        let range = lastWeekRange
        let calendar = Calendar.current
        let twoWeeksAgoStart = calendar.date(byAdding: .day, value: -7, to: range.start)!
        return (twoWeeksAgoStart, range.start)
    }

    private var twoWeeksAgoWorkouts: [Workout] {
        let range = twoWeeksAgoRange
        return allWorkouts.filter { $0.date >= range.start && $0.date < range.end }
    }

    private var volumeChange: Double? {
        let prevVolumeKg = twoWeeksAgoWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
        guard prevVolumeKg > 0 else { return nil }
        let currentVolumeKg = lastWeekWorkouts.reduce(0.0) { total, workout in
            total + workout.exercises.reduce(0.0) { exTotal, exercise in
                exTotal + exercise.sets.filter { !$0.isWarmUp }.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
            }
        }
        return ((currentVolumeKg - prevVolumeKg) / prevVolumeKg) * 100
    }

    private var lastWeekDateLabel: String {
        let range = lastWeekRange
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: range.start)) – \(formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: range.end)!))"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 4) {
                    Text("Weekly Recap")
                        .font(.title2.bold())
                    Text(lastWeekDateLabel)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                if lastWeekWorkouts.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts", systemImage: "figure.walk")
                    } description: {
                        Text("You didn't log any workouts last week. Get after it this week!")
                    }
                    .padding(.top, 40)
                } else {
                    // Main stats grid
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        statCard(
                            icon: "figure.strengthtraining.traditional",
                            value: "\(workoutCount)",
                            label: "Workouts",
                            color: .blue
                        )
                        statCard(
                            icon: "clock",
                            value: formattedDuration,
                            label: "Total Time",
                            color: .green
                        )
                        statCard(
                            icon: "scalemass",
                            value: formatVolume(totalVolume),
                            label: "Volume",
                            color: .purple,
                            change: volumeChange
                        )
                        statCard(
                            icon: "number",
                            value: "\(totalSets)",
                            label: "Sets",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    // PRs
                    if prsHit > 0 {
                        HStack(spacing: 10) {
                            Image(systemName: "star.fill")
                                .font(.title2)
                                .foregroundStyle(.yellow)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(prsHit) Personal Record\(prsHit == 1 ? "" : "s")")
                                    .font(.headline)
                                Text("You set new records last week!")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Average rating
                    if let avgRating = averageRating {
                        HStack(spacing: 10) {
                            HStack(spacing: 2) {
                                ForEach(1...5, id: \.self) { star in
                                    Image(systemName: Double(star) <= avgRating ? "star.fill" : (Double(star) - 0.5 <= avgRating ? "star.leadinghalf.filled" : "star"))
                                        .foregroundStyle(.yellow)
                                }
                            }
                            .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Avg Rating")
                                    .font(.headline)
                                Text(String(format: "%.1f / 5.0", avgRating))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Muscle groups
                    if !muscleGroupsHit.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Muscle Groups Trained")
                                .font(.headline)
                            FlowLayout(spacing: 8) {
                                ForEach(muscleGroupsHit) { group in
                                    HStack(spacing: 4) {
                                        Image(systemName: group.icon)
                                        Text(group.rawValue)
                                    }
                                    .font(.subheadline)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemFill), in: Capsule())
                                }
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }

                    // Workout list
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Workouts")
                            .font(.headline)
                        ForEach(lastWeekWorkouts.sorted { $0.date < $1.date }) { workout in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(workout.name)
                                        .font(.subheadline.weight(.medium))
                                    Text(workout.date, format: .dateTime.weekday(.wide).month().day())
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let duration = workout.formattedDuration {
                                    Text(duration)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let rating = workout.rating, rating > 0 {
                                    HStack(spacing: 1) {
                                        ForEach(1...rating, id: \.self) { _ in
                                            Image(systemName: "star.fill")
                                                .imageScale(.small)
                                        }
                                    }
                                    .foregroundStyle(.yellow)
                                    .font(.caption2)
                                }
                            }
                            .padding(.vertical, 4)
                            if workout.id != lastWeekWorkouts.sorted(by: { $0.date < $1.date }).last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 20)
        }
        .navigationTitle("Last Week")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func statCard(icon: String, value: String, label: String, color: Color, change: Double? = nil) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.title3.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let change {
                HStack(spacing: 2) {
                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .imageScale(.small)
                    Text(String(format: "%+.0f%%", change))
                }
                .font(.caption2.bold())
                .foregroundStyle(change >= 0 ? .green : .red)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    private func formatVolume(_ volume: Double) -> String {
        if volume >= 1000 {
            return String(format: "%.1fk %@", volume / 1000, weightUnit.label)
        }
        return String(format: "%.0f %@", volume, weightUnit.label)
    }
}

#Preview {
    NavigationStack {
        WeeklyRecapView()
    }
    .modelContainer(for: Workout.self, inMemory: true)
}
