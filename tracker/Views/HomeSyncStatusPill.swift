import SwiftUI

/// Slim iCloud-status pill shown on the home dashboard when sync is
/// failing or the account isn't usable. Tap opens a detail sheet that
/// links into system iCloud settings.
struct HomeSyncStatusPill: View {
    @State private var showingDetail = false

    var body: some View {
        let mgr = SyncStatusManager.shared
        let isAccountIssue = !mgr.accountStatus.isHealthy && mgr.accountStatus != .unknown
        let tint: Color = isAccountIssue ? .orange : .yellow
        let title: String = isAccountIssue ? mgr.accountStatus.label : "iCloud sync paused"
        let subtitle: String = isAccountIssue
            ? "Your data isn't backing up. Tap for help."
            : "Recent changes haven't synced. Tap for details."

        return Button { showingDetail = true } label: {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.28), tint.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 30, height: 30)
                        .overlay(Circle().stroke(tint.opacity(0.30), lineWidth: 0.5))
                    Image(systemName: "exclamationmark.icloud.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(tint)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.pressableCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens sync status details")
        .sheet(isPresented: $showingDetail) {
            NavigationStack {
                SyncStatusDetailSheet(manager: mgr)
            }
            .presentationDetents([.medium, .large])
        }
    }

    /// True if the pill should be shown — surfaces explicit errors or
    /// non-healthy account states (excluding the transient `.unknown`).
    static var shouldShow: Bool {
        let mgr = SyncStatusManager.shared
        if mgr.lastError != nil { return true }
        switch mgr.accountStatus {
        case .available, .unknown: return false
        case .noAccount, .restricted, .temporarilyUnavailable: return true
        }
    }
}
