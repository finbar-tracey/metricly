import SwiftUI

/// Sheet that lets the user pick a partner exercise to superset with
/// `source`. Calls back into the parent on selection or cancel — the
/// parent owns the linking logic so this view is purely presentation.
struct SupersetPickerSheet: View {
    let source: Exercise
    let candidates: [Exercise]
    let onPick: (Exercise) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Choose an exercise to superset with \"\(source.name)\".")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Section {
                    ForEach(candidates) { partner in
                        Button {
                            onPick(partner)
                        } label: {
                            HStack {
                                MuscleIconView(group: partner.category ?? .other, color: Color.accentColor)
                                    .frame(width: 18, height: 18)
                                Text(partner.name)
                                if partner.supersetGroup != nil {
                                    Spacer()
                                    Text("SS")
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(.tint.opacity(0.2), in: .capsule)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Exercises")
                }
            }
            .navigationTitle("Link Superset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
    }
}
