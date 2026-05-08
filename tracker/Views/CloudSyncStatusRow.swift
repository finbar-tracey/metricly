import SwiftUI

/// Visual indicator of iCloud account state + last successful sync.
/// Lives in Settings under the "iCloud Sync" section.
struct CloudSyncStatusRow: View {
    let manager: SyncStatusManager
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Account row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(accountIconColor.opacity(0.16))
                        .frame(width: 32, height: 32)
                    Image(systemName: accountIcon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(accountIconColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.accountStatus.label)
                        .font(.subheadline.weight(.semibold))
                    Text(accountSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Divider()

            // Last sync row
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(syncIconColor.opacity(0.16))
                        .frame(width: 32, height: 32)
                    if manager.isSyncing {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: syncIcon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(syncIconColor)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncTitle)
                        .font(.subheadline.weight(.semibold))
                    Text(syncSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            // Error state, if any
            if let error = manager.lastError, !manager.isSyncing {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await manager.refreshAccountStatus() }
            }
        }
    }

    // MARK: - Account row

    private var accountIcon: String {
        switch manager.accountStatus {
        case .available:              return "icloud.fill"
        case .restricted:             return "icloud.slash.fill"
        case .noAccount:              return "icloud.slash"
        case .temporarilyUnavailable: return "exclamationmark.icloud.fill"
        case .unknown:                return "questionmark.circle"
        }
    }

    private var accountIconColor: Color {
        switch manager.accountStatus {
        case .available:              return .blue
        case .restricted, .noAccount: return .orange
        case .temporarilyUnavailable: return .yellow
        case .unknown:                return .secondary
        }
    }

    private var accountSubtitle: String {
        switch manager.accountStatus {
        case .available:
            return "Data is being backed up to your iCloud account"
        case .noAccount:
            return "Sign in to iCloud in Settings to enable backup"
        case .restricted:
            return "iCloud is restricted by parental controls or MDM"
        case .temporarilyUnavailable:
            return "iCloud is temporarily unavailable — try again later"
        case .unknown:
            return "Checking your iCloud account…"
        }
    }

    // MARK: - Sync row

    private var syncIcon: String {
        if manager.lastError != nil { return "exclamationmark.triangle.fill" }
        return manager.lastSuccessfulSync == nil ? "clock" : "checkmark.circle.fill"
    }

    private var syncIconColor: Color {
        if manager.isSyncing { return .blue }
        if manager.lastError != nil { return .orange }
        return manager.lastSuccessfulSync == nil ? .secondary : .green
    }

    private var syncTitle: String {
        if manager.isSyncing { return "Syncing…" }
        return "Last sync"
    }

    private var syncSubtitle: String {
        if manager.isSyncing { return "Uploading or downloading changes" }
        return manager.formattedLastSync
    }
}
