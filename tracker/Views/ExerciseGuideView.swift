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
        List {
            if let guide {
                Section {
                    Text(guide.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(guide.primaryMuscles, id: \.self) { muscle in
                        HStack(spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Color.accentColor)
                            Text(muscle)
                                .font(.subheadline)
                        }
                    }
                    ForEach(guide.secondaryMuscles, id: \.self) { muscle in
                        HStack(spacing: 8) {
                            Image(systemName: "circle")
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                            Text(muscle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("Target Muscles", systemImage: "figure.strengthtraining.traditional")
                } footer: {
                    Text("Filled = primary muscles, outlined = secondary muscles.")
                }

                Section {
                    ForEach(Array(guide.formTips.enumerated()), id: \.offset) { index, tip in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 22, height: 22)
                                .background(Color.accentColor, in: Circle())
                            Text(tip)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Label("Form Tips", systemImage: "checkmark.seal")
                }

                Section {
                    ForEach(guide.commonMistakes, id: \.self) { mistake in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.subheadline)
                            Text(mistake)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Label("Common Mistakes", systemImage: "exclamationmark.triangle")
                }
            } else {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "text.book.closed")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No form guide available")
                            .font(.headline)
                        Text("Form guidance isn't available yet for \"\(exerciseName)\". Guides cover the most common exercises.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Form Guide")
        .navigationBarTitleDisplayMode(.inline)
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

                // Primary muscles as compact tags
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

                // Top 3 form tips
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
