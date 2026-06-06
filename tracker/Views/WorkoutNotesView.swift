import SwiftUI

struct WorkoutNotesView: View {
    @Bindable var workout: Workout
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.sectionSpacing) {
                if isEditing {
                    editingCard
                } else if workout.notes.isEmpty {
                    emptyStateCard
                } else {
                    notesDisplayCard
                    formattingGuideCard
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 36)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Workout Notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") {
                        workout.notes = editText
                        isEditing = false
                    }
                    .fontWeight(.semibold)
                } else {
                    Button {
                        editText = workout.notes
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Edit notes")
                }
            }
        }
    }

    // MARK: - Notes Display

    private var notesDisplayCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Notes", icon: "note.text", color: .accentColor)
            Text(LocalizedStringKey(workout.notes))
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.06), Color(.tertiarySystemGroupedBackground)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.12), lineWidth: 0.5)
                )
        }
        .appCard()
    }

    // MARK: - Editing Card

    private var editingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Edit Notes", icon: "pencil.circle.fill", color: .accentColor)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    formatButton("Bold", icon: "bold") { insertFormatting("**", "**") }
                    formatButton("Italic", icon: "italic") { insertFormatting("*", "*") }
                    formatButton("Heading", icon: "number") { insertFormatting("## ", "") }
                    formatButton("Bullet", icon: "list.bullet") { insertFormatting("- ", "") }
                    formatButton("Checkbox", icon: "checkmark.square") { insertFormatting("- [ ] ", "") }
                }
            }

            TextEditor(text: $editText)
                .frame(minHeight: 200)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))

            if !editText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(LocalizedStringKey(editText))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
                }
            }
        }
        .appCard()
    }

    private func formatButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.16), Color.accentColor.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Color.accentColor.opacity(0.20), lineWidth: 0.5)
                )
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel(label)
        .buttonStyle(.pressableCard)
    }

    private func insertFormatting(_ prefix: String, _ suffix: String) {
        editText += prefix + "text" + suffix
    }

    // MARK: - Formatting Guide Card

    private var formattingGuideCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Formatting Tips", icon: "text.badge.star", color: .secondary)

            VStack(spacing: 0) {
                tipRow(syntax: "**bold**", result: "**bold**")
                Divider().padding(.leading, 16)
                tipRow(syntax: "*italic*", result: "*italic*")
                Divider().padding(.leading, 16)
                tipRow(syntax: "## Heading", result: "Heading")
                Divider().padding(.leading, 16)
                tipRow(syntax: "- item", result: "• item")
            }
            .background(Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius))
        }
        .appCard()
    }

    private func tipRow(syntax: String, result: String) -> some View {
        HStack(spacing: 12) {
            Text(syntax).font(.caption.monospaced()).foregroundStyle(.secondary)
            Spacer()
            Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.tertiary)
            Spacer()
            Text(LocalizedStringKey(result)).font(.caption).frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Empty State

    private var emptyStateCard: some View {
        VStack(spacing: 22) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.22), Color.accentColor.opacity(0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 86, height: 86)
                    .overlay(Circle().stroke(Color.accentColor.opacity(0.18), lineWidth: 1))
                Image(systemName: "note.text")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(spacing: 8) {
                Text("No Notes Yet")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                Text("Add notes about this workout — techniques, feelings, PRs, or anything worth remembering.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                editText = workout.notes
                isEditing = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text("Add Notes")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .tracking(0.4)
                }
                .padding(.horizontal, 28).padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.78)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 0.5))
                .shadow(color: Color.accentColor.opacity(0.45), radius: 12, y: 5)
            }
            .buttonStyle(.pressableCard)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }
}

#Preview {
    NavigationStack { WorkoutNotesView(workout: Workout(name: "Test")) }
}
