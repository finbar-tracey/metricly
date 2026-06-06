import SwiftUI
import UIKit

enum CardioCompletionActionsSection {
    @ViewBuilder
    static func content<StravaPill: View>(
        session: CardioSession,
        useKm: Bool,
        notes: Binding<String>,
        notesFocused: FocusState<Bool>.Binding,
        appeared: Bool,
        stravaUpload: StravaUploadState,
        onDone: @escaping () -> Void,
        @ViewBuilder stravaStatusPill: () -> StravaPill
    ) -> some View {
        if stravaUpload != .idle {
            stravaStatusPill()
                .padding(.horizontal, 24)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }

        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text("Add a note")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .textCase(.uppercase)
            } icon: {
                Image(systemName: "note.text").font(.caption.bold())
            }
            .foregroundStyle(.white.opacity(0.78))
            TextField("How did it feel?", text: notes, axis: .vertical)
                .lineLimit(2...4)
                .font(.subheadline)
                .foregroundStyle(.white)
                .tint(.white)
                .focused(notesFocused)
                .padding(14)
                .background(.ultraThinMaterial.opacity(0.55), in: RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous)
                        .stroke(.white.opacity(0.20), lineWidth: 0.5)
                )
        }
        .padding(.horizontal, 24)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.52), value: appeared)

        Spacer(minLength: 16)

        VStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                session.notes = notes.wrappedValue
                onDone()
            } label: {
                Text("View Full Report")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(.white)
                    .foregroundStyle(session.type.color)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                    .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
            }
            .buttonStyle(.pressableCard)

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                let img = renderCardioShareImage(session: session, useKm: useKm)
                guard let img else { return }
                let av = UIActivityViewController(activityItems: [img], applicationActivities: nil)
                if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let root = scene.windows.first?.rootViewController {
                    root.present(av, animated: true)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share Run")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(.ultraThinMaterial.opacity(0.65), in: RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: AppTheme.miniCardRadius, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 0.5)
                )
            }
            .buttonStyle(.pressableCard)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 40)
        .opacity(appeared ? 1 : 0)
        .animation(.easeOut(duration: 0.4).delay(0.55), value: appeared)
    }
}
