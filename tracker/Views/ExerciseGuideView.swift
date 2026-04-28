import SwiftUI

// MARK: - Navigation Destination

struct FormGuideDestination: Hashable {
    let exerciseName: String
}

// MARK: - Full Page View

struct ExerciseGuideView: View {
    let exerciseName: String

    private var guide: ExerciseGuide? {
        ExerciseGuide.find(exerciseName)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if let guide {
                    guideHeroCard(guide: guide)
                    descriptionCard(guide: guide)
                    musclesCard(guide: guide)
                    if !guide.formTips.isEmpty { formTipsCard(guide: guide) }
                    if !guide.commonMistakes.isEmpty { mistakesCard(guide: guide) }
                } else {
                    emptyCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Form Guide")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Cards

    private func guideHeroCard(guide: ExerciseGuide) -> some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(
                colors: [Color.indigo, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle().fill(.white.opacity(0.07)).frame(width: 160).offset(x: 100, y: -20)
            Circle().fill(.white.opacity(0.05)).frame(width: 80).offset(x: -10, y: 60)

            VStack(alignment: .leading, spacing: 10) {
                Label("Form Guide", systemImage: "text.book.closed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.2), in: .capsule)

                Text(exerciseName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                HStack(spacing: 12) {
                    Label("\(guide.primaryMuscles.count) primary", systemImage: "circle.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                    Label("\(guide.formTips.count) tips", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(20)
        }
        .frame(minHeight: 140)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius))
    }

    private func descriptionCard(guide: ExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Overview", icon: "info.circle.fill", color: .indigo)
            Text(guide.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .appCard()
    }

    private func musclesCard(guide: ExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Target Muscles", icon: "figure.strengthtraining.traditional", color: .red)

            if !guide.primaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Primary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(guide.primaryMuscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(.red.opacity(0.12), in: .capsule)
                        }
                    }
                }
            }

            if !guide.secondaryMuscles.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Secondary")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    FlowLayout(spacing: 6) {
                        ForEach(guide.secondaryMuscles, id: \.self) { muscle in
                            Text(muscle)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color(.tertiarySystemFill), in: .capsule)
                        }
                    }
                }
            }
        }
        .appCard()
    }

    private func formTipsCard(guide: ExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Form Tips", icon: "checkmark.seal.fill", color: .green)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(guide.formTips.enumerated()), id: \.offset) { index, tip in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundStyle(.green)
                        }
                        Text(tip)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    if index < guide.formTips.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 4)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private func mistakesCard(guide: ExerciseGuide) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "Common Mistakes", icon: "exclamationmark.triangle.fill", color: .orange)
                .padding(.bottom, 12)

            VStack(spacing: 0) {
                ForEach(Array(guide.commonMistakes.enumerated()), id: \.offset) { index, mistake in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "exclamationmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        Text(mistake)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)

                    if index < guide.commonMistakes.count - 1 {
                        Divider().padding(.leading, 40)
                    }
                }
            }
            .padding(.horizontal, 4)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
        .appCard()
    }

    private var emptyCard: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color(.tertiarySystemFill)).frame(width: 72, height: 72)
                Image(systemName: "text.book.closed")
                    .font(.system(size: 30))
                    .foregroundStyle(.secondary)
            }
            Text("No Guide Available")
                .font(.headline)
            Text("Form guidance isn't available for \"\(exerciseName)\" yet. Guides cover the most common exercises.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .appCard()
    }
}

// MARK: - Collapsible Inline Section

struct ExerciseGuideSectionView: View {
    let exerciseName: String
    @State private var isExpanded = false

    private var guide: ExerciseGuide? {
        ExerciseGuide.find(exerciseName)
    }

    var body: some View {
        if let guide {
            Section(isExpanded: $isExpanded) {
                Text(guide.description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)

                FlowLayout(spacing: 6) {
                    ForEach(guide.primaryMuscles, id: \.self) { muscle in
                        Text(muscle)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.12), in: Capsule())
                    }
                    ForEach(guide.secondaryMuscles, id: \.self) { muscle in
                        Text(muscle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.tertiarySystemFill), in: Capsule())
                    }
                }
                .padding(.vertical, 2)

                ForEach(guide.formTips.prefix(3), id: \.self) { tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text(tip)
                            .font(.caption)
                    }
                }

                NavigationLink(value: FormGuideDestination(exerciseName: exerciseName)) {
                    Label("View full form guide", systemImage: "text.book.closed")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }
            } header: {
                HStack {
                    Label("Form Guide", systemImage: "text.book.closed")
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation { isExpanded.toggle() }
                }
            }
        }
    }
}

#Preview("Full Guide") {
    NavigationStack {
        ExerciseGuideView(exerciseName: "Bench Press")
    }
}

#Preview("No Guide") {
    NavigationStack {
        ExerciseGuideView(exerciseName: "Custom Exercise XYZ")
    }
}
