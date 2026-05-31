import SwiftUI

/// Gradient SF Symbol tile used across Settings section rows.
func settingsSectionIcon(_ name: String, color: Color) -> some View {
    ZStack {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [color, color.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 30, height: 30)
            .shadow(color: color.opacity(0.40), radius: 4, y: 2)
        Image(systemName: name)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
    }
}
