import SwiftUI

/// The floating glass tab bar from the v2 handoff, over the app's existing four
/// tabs.
///
/// Two deliberate departures from the design reference:
///
/// - **Tabs are the app's, not the handoff's.** The reference shows Today /
///   Plan / Trends / You, which is a different information architecture, not a
///   restyle. This is the chrome only.
/// - **The accent follows the user's Settings accent color**, not the brand
///   green the reference hardcodes. That setting already tints the system tab
///   bar today, and quietly overriding it would be a regression.
struct MetriclyTabBar: View {
    @Binding var selection: ContentView.AppTab
    var accent: Color = AppTheme.Dark.Signal.recovery

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Item {
        let tab: ContentView.AppTab
        let label: LocalizedStringKey
        let symbol: String
    }

    private let items: [Item] = [
        .init(tab: .home, label: "Home", symbol: "house"),
        .init(tab: .training, label: "Training", symbol: "figure.strengthtraining.traditional"),
        .init(tab: .health, label: "Health", symbol: "heart.text.square"),
        .init(tab: .more, label: "More", symbol: "ellipsis.circle")
    ]

    /// The reference specifies bare `.ultraThinMaterial` over a dark page. This
    /// bar also floats over the Start CTA — a full-width accent fill — where
    /// thin material alone drops the inactive labels to unreadable. A scrim
    /// behind the glass keeps the depth without betting legibility on whatever
    /// happens to scroll underneath.
    private let scrim = AppTheme.Dark.bgInset.opacity(0.72)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.tab) { item in
                button(for: item)
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(scrim)
                )
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(AppTheme.Dark.hairline, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 15, y: 10)
        .padding(.horizontal, 12)
        // Fixed-height chrome: let it grow a little, not unboundedly.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        // The bar is dark on every tab, not just the redesigned Home. It spans
        // all four, so following the page would make it flip appearance mid-app;
        // holding it dark reads as one piece of chrome — the same reasoning the
        // handoff applies to widgets ("they read as instruments"). Pinning the
        // scheme also keeps `.ultraThinMaterial` from resolving light.
        .environment(\.colorScheme, .dark)
    }

    private func button(for item: Item) -> some View {
        let isSelected = item.tab == selection
        let tint = isSelected ? accent : AppTheme.Dark.text4

        return Button {
            guard !isSelected else { return }
            HapticsManager.selectionChanged()
            if reduceMotion {
                selection = item.tab
            } else {
                withAnimation(.snappy(duration: 0.2)) { selection = item.tab }
            }
        } label: {
            VStack(spacing: 3) {
                Image(systemName: item.symbol)
                    .scaledFont(size: 17, weight: isSelected ? .semibold : .regular)
                    .symbolVariant(isSelected ? .fill : .none)
                Text(item.label)
                    .scaledFont(size: 10, weight: .bold, design: .monospaced)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .overlay(alignment: .top) {
                // The lit tick is the whole selected state at a glance — the
                // glyph alone reads as too quiet at this size.
                if isSelected {
                    Capsule()
                        .fill(accent)
                        .frame(width: 26, height: 2.5)
                        .signalGlow(accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Hiding

/// Set by any screen that needs the bar out of the way — the live workout,
/// per the handoff ("Live workout hides it entirely").
private struct MetriclyTabBarHiddenKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    func hidesMetriclyTabBar(_ hidden: Bool = true) -> some View {
        preference(key: MetriclyTabBarHiddenKey.self, value: hidden)
    }

    /// Reads the flag above. Applied once, by the tab container.
    func onMetriclyTabBarHiddenChange(_ action: @escaping (Bool) -> Void) -> some View {
        onPreferenceChange(MetriclyTabBarHiddenKey.self) { action($0) }
    }
}

#Preview {
    @Previewable @State var selection: ContentView.AppTab = .home

    VStack {
        Spacer()
        MetriclyTabBar(selection: $selection)
    }
    .background(AppTheme.Dark.bg)
    .preferredColorScheme(.dark)
}
