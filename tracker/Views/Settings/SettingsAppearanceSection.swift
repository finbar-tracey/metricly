import SwiftUI

struct SettingsAppearanceSection: View {
    let settings: UserSettings

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Label("Accent Color", systemImage: "paintpalette")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(AppAccentColor.allCases) { item in
                        let isSelected = settings.accentColor == item
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
                                settings.accentColor = item
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(item.color.gradient)
                                    .frame(width: 34, height: 34)
                                    .shadow(color: isSelected ? item.color.opacity(0.5) : .clear, radius: 6, x: 0, y: 2)
                                if isSelected {
                                    Circle().strokeBorder(.white, lineWidth: 2.5).frame(width: 34, height: 34)
                                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                                }
                            }
                            .scaleEffect(isSelected ? 1.18 : 1.0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.rawValue)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
            .padding(.vertical, 6)

            HStack(spacing: 12) {
                settingsSectionIcon("circle.lefthalf.filled", color: .indigo)
                Picker("Appearance", selection: Binding(
                    get: { settings.appearanceMode },
                    set: { settings.appearanceMode = $0 }
                )) {
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("System").tag("system")
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Appearance")
                .accessibilityHint("Choose light, dark, or system theme")
            }
        } header: {
            Text("Appearance")
        } footer: {
            Text("Light or Dark, or follow your device with System. Synced via iCloud when enabled.")
        }
    }
}
