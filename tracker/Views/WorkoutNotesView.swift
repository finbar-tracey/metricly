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
                .padding(16)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 14))
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
                .clipShape(RoundedRectangle(cornerRadius: 14))

            if !editText.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Preview").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    Text(LocalizedStringKey(editText))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .appCard()
    }

    private func formatButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .frame(width: 38, height: 38)
                .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel(label)
        .buttonStyle(.plain)
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
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 70, height: 70)
                Image(systemName: "note.text")
                    .font(.system(size: 28, weight: .semibold)).foregroundStyle(Color.accentColor)
            }
            VStack(spacing: 6) {
                Text("No Notes Yet").font(.headline)
                Text("Add notes about this workout — techniques, feelings, PRs, or anything worth remembering.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            Button {
                editText = workout.notes
                isEditing = true
            } label: {
                Text("Add Notes")
                    .font(.subheadline.bold()).padding(.horizontal, 24).padding(.vertical, 12)
                    .background(Color.accentColor.gradient).foregroundStyle(.white).clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
        .appCard()
    }
}

#Preview {
    NavigationStack { WorkoutNotesView(workout: Workout(name: "Test")) }
}
