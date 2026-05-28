import SwiftUI

/// Tiny pub-sub bus for surfacing app-wide errors as a slim banner.
/// Many `try?` sites throughout the app silently swallow failures
/// (HealthKit saves, Strava uploads, CloudKit writes). The intent isn't
/// to migrate them all at once — it's to provide a uniform primitive
/// so when a caller does have a user-presentable error, surfacing it
/// is one line.
///
/// Usage:
/// ```swift
/// AppErrorBus.shared.report(message: "Couldn't save to Apple Health")
/// ```
/// The root view (`ContentView`) renders `ErrorBanner()` in a
/// `safeAreaInset(.top)` — it auto-dismisses after 4 seconds and can
/// be swiped/tapped away early.
@MainActor
@Observable
final class AppErrorBus {
    static let shared = AppErrorBus()

    private(set) var current: BannerError?

    nonisolated struct BannerError: Identifiable, Equatable, Sendable {
        let id = UUID()
        let message: String
        let kind: Kind

        nonisolated enum Kind: Equatable, Sendable {
            case warning   // amber
            case failure   // red
            case info      // blue
        }
    }

    func report(message: String, kind: BannerError.Kind = .failure) {
        current = BannerError(message: message, kind: kind)
        // Auto-dismiss after 4 seconds; cancel if a new banner arrives.
        let myID = current?.id
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard let self, self.current?.id == myID else { return }
            self.current = nil
        }
    }

    func dismiss() { current = nil }

    private init() {}
}

/// Slim top banner that shows whatever's currently on `AppErrorBus.shared`.
/// Renders nothing when there's no active error. Designed to live inside
/// a `safeAreaInset(.top)` so it slides under the status bar without
/// displacing content.
struct ErrorBanner: View {
    @State private var bus = AppErrorBus.shared

    var body: some View {
        Group {
            if let err = bus.current {
                bannerContent(err)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: bus.current)
    }

    private func bannerContent(_ err: AppErrorBus.BannerError) -> some View {
        let tint: Color = {
            switch err.kind {
            case .warning: return .orange
            case .failure: return .red
            case .info:    return .blue
            }
        }()
        let icon: String = {
            switch err.kind {
            case .warning: return "exclamationmark.triangle.fill"
            case .failure: return "xmark.octagon.fill"
            case .info:    return "info.circle.fill"
            }
        }()

        return HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline.bold())
                .foregroundStyle(tint)
            Text(err.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button {
                AppErrorBus.shared.dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(tint.opacity(0.28), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .onTapGesture { AppErrorBus.shared.dismiss() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Error: \(err.message). Tap to dismiss.")
    }
}
