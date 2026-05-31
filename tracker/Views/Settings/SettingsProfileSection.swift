import SwiftUI

struct SettingsProfileSection: View {
    let settings: UserSettings

    var body: some View {
        Section {
            NavigationLink(value: SettingsRoute.profile) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [Color.accentColor, Color.accentColor.opacity(0.72)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 54, height: 54)
                            .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 3)
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(settings.userName.isEmpty ? "Your Name" : settings.userName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(settings.userName.isEmpty ? .secondary : .primary)
                        Text(profileSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }

    private var profileSubtitle: String {
        var parts: [String] = []
        parts.append(settings.useKilograms ? "Kilograms" : "Pounds")
        if settings.biologicalSex == "male"   { parts.append("Male") }
        if settings.biologicalSex == "female" { parts.append("Female") }
        return parts.joined(separator: " · ")
    }
}
