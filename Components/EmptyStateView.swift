import SwiftUI

/// Single empty-state primitive for "no data yet" screens. Each card
/// previously rolled its own variation — different icon sizes, different
/// spacings, sometimes missing the CTA. Adopting this one component
/// gives every empty surface the same look and ensures the action button
/// always shows up.
///
/// Action is optional — pass `nil` for screens where the user can't do
/// anything from the empty state (e.g. "no health data yet" depends on
/// HealthKit auth, not a button on this screen).
struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    let action: Action?

    struct Action {
        let label: String
        let perform: () -> Void
    }

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        action: Action? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let action {
                Button(action: action.perform) {
                    Text(action.label)
                        .font(.subheadline.bold())
                        .padding(.horizontal, 22)
                        .padding(.vertical, 11)
                        .background(Color.accentColor.gradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.pressableCard)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle ?? "")")
    }
}
