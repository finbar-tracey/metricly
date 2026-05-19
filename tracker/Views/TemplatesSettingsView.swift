import SwiftUI
import SwiftData

/// Lists the user's saved workout templates with quick-edit, delete, and a
/// jump-off to the Template Marketplace. Reached from the Templates row in
/// `SettingsView` via `SettingsRoute.templates`. Relies on the parent's
/// `navigationDestination(for: Workout.self)` and the string-routed
/// `"templateMarketplace"` destination — both live in `SettingsView`.
struct TemplatesSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(filter: #Predicate<Workout> { $0.isTemplate }, sort: \Workout.name)
    private var templates: [Workout]
    @State private var creatingTemplate: Workout?

    var body: some View {
        Form {
            Section {
                NavigationLink(value: "templateMarketplace") {
                    HStack(spacing: 12) {
                        Image(systemName: "square.grid.2x2.fill")
                            .foregroundStyle(.purple)
                        Text("Browse Template Marketplace")
                    }
                }
                Button {
                    addTemplate()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.green)
                        Text("Create New Template")
                    }
                }
            }

            Section {
                if templates.isEmpty {
                    Text("No templates yet. Create one or grab a starter from the marketplace.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(templates) { template in
                        NavigationLink(value: template) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(template.name.isEmpty ? "Untitled" : template.name)
                                    .font(.subheadline.weight(.semibold))
                                Text(summary(for: template))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteTemplates)
                }
            } header: {
                Text("Your templates")
            }
        }
        .navigationTitle("Templates")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $creatingTemplate) { template in
            TemplateEditView(template: template)
        }
    }

    private func summary(for template: Workout) -> String {
        let count = template.exercises.count
        return count == 0
            ? "Empty"
            : "\(count) exercise\(count == 1 ? "" : "s")"
    }

    private func addTemplate() {
        let template = Workout(name: "New Template", isTemplate: true)
        modelContext.insert(template)
        creatingTemplate = template
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
    }
}
