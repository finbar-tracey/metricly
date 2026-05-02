import SwiftUI

func hubRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
    HStack(spacing: 14) {
        ZStack {
            RoundedRectangle(cornerRadius: 11)
                .fill(color.gradient)
                .frame(width: 40, height: 40)
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
        }
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    .padding(.vertical, 3)
}
