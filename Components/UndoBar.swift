import SwiftUI

/// Reusable undo snackbar shown at the bottom of the screen after a destructive-reversible action.
struct UndoBar: View {
    let icon: String
    let message: String
    let color: Color
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(message)
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("Undo", action: onUndo)
                .font(.subheadline.bold())
                .foregroundStyle(color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
