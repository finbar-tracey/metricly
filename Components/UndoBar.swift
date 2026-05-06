import SwiftUI

/// Reusable undo snackbar shown at the bottom of the screen after a destructive-reversible action.
struct UndoBar: View {
    let icon: String
    let message: String
    let color: Color
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(color)
            }
            Text(message)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer()
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onUndo()
            } label: {
                Text("Undo")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        LinearGradient(
                            colors: [color, color.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Capsule()
                    )
                    .shadow(color: color.opacity(0.40), radius: 6, y: 3)
            }
            .buttonStyle(.pressableCard)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 5)
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
