import SwiftUI
import SwiftData

enum CardioSessionActionsSection {
    static func shouldShowStravaPill(
        isConnected: Bool,
        session: CardioSession,
        upload: StravaUploadState
    ) -> Bool {
        if !isConnected { return false }
        if session.stravaActivityID != nil { return true }
        switch upload {
        case .idle: return false
        default: return true
        }
    }

    static func stravaMenuLabel(session: CardioSession, upload: StravaUploadState) -> String {
        if session.stravaActivityID != nil { return "Already on Strava" }
        switch upload {
        case .uploading: return "Pushing to Strava…"
        case .failed: return "Retry push to Strava"
        default: return "Push to Strava"
        }
    }

    @ViewBuilder
    static func stravaStatusPill(session: CardioSession, upload: StravaUploadState, onRetry: @escaping () -> Void) -> some View {
        let tint: Color = {
            switch upload {
            case .failed: return .red
            case .success, .duplicate: return .green
            case .uploading, .idle:
                return session.stravaActivityID != nil ? .green : .orange
            }
        }()
        let icon: String = {
            switch upload {
            case .uploading: return "arrow.up.circle"
            case .failed: return "exclamationmark.triangle.fill"
            case .success, .duplicate: return "checkmark.circle.fill"
            case .idle:
                return session.stravaActivityID != nil ? "checkmark.circle.fill" : "figure.run.circle"
            }
        }()
        let title: String = {
            switch upload {
            case .uploading: return "Pushing to Strava…"
            case .success: return "Pushed to Strava"
            case .duplicate: return "Already on Strava"
            case .failed(let msg): return "Strava push failed: \(msg)"
            case .idle:
                return session.stravaActivityID != nil ? "Pushed to Strava" : ""
            }
        }()

        HStack(spacing: 10) {
            if case .uploading = upload {
                ProgressView().tint(tint)
            } else {
                Image(systemName: icon).font(.subheadline.bold()).foregroundStyle(tint)
            }
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
            if case .failed = upload {
                Button("Retry", action: onRetry)
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.25), lineWidth: 1)
        )
    }

    @MainActor
    static func uploadToStrava(
        session: CardioSession,
        strava: StravaService,
        modelContext: ModelContext,
        upload: Binding<StravaUploadState>
    ) {
        guard !upload.wrappedValue.isInFlight else { return }
        upload.wrappedValue = .uploading
        Task {
            do {
                let activity = try await strava.uploadActivity(session)
                await MainActor.run {
                    session.stravaActivityID = activity.id
                    try? modelContext.save()
                    upload.wrappedValue = .success
                }
            } catch StravaError.duplicateActivity {
                await MainActor.run { upload.wrappedValue = .duplicate }
            } catch {
                await MainActor.run {
                    upload.wrappedValue = .failed(error.localizedDescription)
                }
            }
        }
    }
}
