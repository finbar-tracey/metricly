import SwiftUI

struct WorkoutNotesView: View {
    @Bindable var workout: Workout
    @State private var isEditing = false
    @State private var editText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isEditing {
                    editingView
                } else {
                    if workout.notes.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "note.text")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No notes yet")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("Add workout notes with formatting support.")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            Button("Add Notes") {
                                editText = workout.notes
                                isEditing = true
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        Text(LocalizedStringKey(workout.notes))
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                if !isEditing && !workout.notes.isEmpty {
                    Divider()
                    formattingGuide
                }
            }
            .padding()
        }
        .navigationTitle("Workout Notes")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button("Done") {
                        workout.notes = editText
                        isEditing = false
                    }
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

    private var editingView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Quick formatting toolbar
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    formatButton("Bold", icon: "bold") {
                        insertFormatting("**", "**")
                    }
                    formatButton("Italic", icon: "italic") {
                        insertFormatting("*", "*")
                    }
                    formatButton("Heading", icon: "number") {
                        insertFormatting("## ", "")
                    }
                    formatButton("Bullet", icon: "list.bullet") {
                        insertFormatting("- ", "")
                    }
                    formatButton("Checkbox", icon: "checkmark.square") {
                        insertFormatting("- [ ] ", "")
                    }
                }
            }

            TextEditor(text: $editText)
                .frame(minHeight: 200)
                .font(.body.monospaced())
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

            // Preview
            if !editText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Preview")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Text(LocalizedStringKey(editText))
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func formatButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.subheadline)
                .frame(width: 36, height: 36)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
        .accessibilityLabel(label)
    }

    private func insertFormatting(_ prefix: String, _ suffix: String) {
        editText += prefix + "text" + suffix
    }

    private var formattingGuide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Formatting Tips")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            Group {
                HStack(spacing: 8) {
                    Text("**bold**").font(.caption.monospaced())
                    Text("->").font(.caption).foregroundStyle(.tertiary)
                    Text("**bold**").font(.caption)
                }
                HStack(spacing: 8) {
                    Text("*italic*").font(.caption.monospaced())
                    Text("->").font(.caption).foregroundStyle(.tertiary)
                    Text("*italic*").font(.caption)
                }
                HStack(spacing: 8) {
                    Text("## Heading").font(.caption.monospaced())
                    Text("->").font(.caption).foregroundStyle(.tertiary)
                    Text("Heading").font(.caption.bold())
                }
                HStack(spacing: 8) {
                    Text("- item").font(.caption.monospaced())
                    Text("->").font(.caption).foregroundStyle(.tertiary)
                    Text("• item").font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        WorkoutNotesView(workout: Workout(name: "Test"))
    }
}
