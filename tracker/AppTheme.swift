import SwiftUI

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
