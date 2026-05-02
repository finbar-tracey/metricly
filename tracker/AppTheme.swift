import SwiftUI
import SwiftData

// MARK: - Design tokens

enum AppTheme {
    static let heroRadius: CGFloat = 28
    static let cardRadius: CGFloat = 20
    static let sectionSpacing: CGFloat = 28
    static let cardPadding: CGFloat = 18
}

// MARK: - View modifiers

extension View {
    func appCard(padding: CGFloat = AppTheme.cardPadding) -> some View {
        self
            .padding(padding)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardRadius))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 4)
    }

    func heroCard() -> some View {
        self
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.heroRadius))
            .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 8)
    }
}

// MARK: - Shared components

struct SectionHeader: View {
    let title: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.leading, 2)
    }
}

struct GradientProgressBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.opacity(0.15))
                    .frame(height: height)
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color.gradient)
                    .frame(width: geo.size.width * min(1, max(0, value)), height: height)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: value)
            }
        }
        .frame(height: height)
    }
}

// MARK: - HeroStatCol
// Replaces the ~14 private heroStatCol / heroStatColumn copies spread across views.
// Used inside gradient hero cards; always white text.

struct HeroStatCol: View {
    let value: String
    let label: String
    var icon:  String? = nil

    var body: some View {
        VStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .monospacedDigit()
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.68))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - CapsuleSegmentPicker
// Replaces the ~6 identical animated capsule pickers in detail views.

struct CapsuleSegmentPicker<T: Hashable & RawRepresentable>: View where T.RawValue == String {
    let options: [T]
    @Binding var selection: T
    var activeColor: Color = .accentColor

    var body: some View {
        HStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        selection = option
                    }
                } label: {
                    Text(option.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == option ? .white : .primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            selection == option
                                ? AnyShapeStyle(activeColor)
                                : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                            in: Capsule()
                        )
                        .shadow(color: selection == option ? activeColor.opacity(0.35) : .clear,
                                radius: 8, x: 0, y: 3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - ModelContext helpers

extension ModelContext {
    /// Saves the context and logs any error instead of silently swallowing it.
    func saveOrLog(file: String = #fileID, line: Int = #line) {
        do {
            try save()
        } catch {
            print("SwiftData save error [\(file):\(line)]: \(error)")
        }
    }
}

// MARK: - Notification names

extension Notification.Name {
    /// Posted by AppDelegate when the user taps a workout reminder notification.
    /// ContentView observes this to switch to the Training tab.
    static let openTrainingTab = Notification.Name("openTrainingTab")
}
