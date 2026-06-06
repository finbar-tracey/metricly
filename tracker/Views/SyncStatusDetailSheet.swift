import SwiftUI
import UIKit

/// Sheet shown from the HomeDashboard's sync-status pill (and reachable
/// elsewhere) when iCloud sync is unhealthy. Explains what's happening,
/// reuses the same CloudSyncStatusRow as Settings, and offers a deep link
/// into system iCloud settings when the issue is account-level.
struct SyncStatusDetailSheet: View {
    let manager: SyncStatusManager
    @Environment(\.appServices) private var appServices
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Headline + explanation
                VStack(alignment: .leading, spacing: 6) {
                    Text(headline)
                        .font(.title3.weight(.semibold))
                    Text(explainer)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Reuse the Settings row for the actual status display so the
                // two surfaces never drift.
                VStack(alignment: .leading, spacing: 0) {
                    CloudSyncStatusRow(manager: manager)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                }
                .background(Color(.secondarySystemGroupedBackground),
                            in: RoundedRectangle(cornerRadius: AppTheme.tileRadius))

                if shouldShowOpenSettingsButton {
                    Button {
                        openSystemSettings()
                    } label: {
                        Label(openSettingsLabel, systemImage: "gear")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.accentColor.opacity(0.15),
                                        in: RoundedRectangle(cornerRadius: 12))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                // Recovery tips footer — passive copy, not interactive.
                if let tips = recoveryTips {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Try this")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.4)
                        ForEach(tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundStyle(.secondary)
                                Text(tip)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color(.tertiarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .navigationTitle("iCloud Sync")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await manager.refreshAccountStatus() }
            }
        }
    }

    // MARK: - Copy

    private var headline: String {
        if !manager.accountStatus.isHealthy && manager.accountStatus != .unknown {
            return manager.accountStatus.label
        }
        if manager.lastError != nil {
            return "Sync paused"
        }
        return "iCloud Sync"
    }

    private var explainer: String {
        switch manager.accountStatus {
        case .noAccount:
            return "You're not signed into iCloud, so your workouts aren't backing up between devices. Sign in to keep your data safe."
        case .restricted:
            return "Parental controls or device management are blocking iCloud on this device. Reach out to whoever manages this device to enable iCloud Drive."
        case .temporarilyUnavailable:
            return "iCloud isn't reachable right now. The app will keep trying — your data is safe on this device in the meantime."
        case .available, .unknown:
            if manager.lastError != nil {
                return "Recent changes haven't synced to iCloud. Most of the time this clears up on its own — your local data is fine."
            }
            return "Your workouts are backed up to iCloud and shared across your devices automatically."
        }
    }

    private var shouldShowOpenSettingsButton: Bool {
        switch manager.accountStatus {
        case .noAccount, .restricted: return true
        default:                       return false
        }
    }

    private var openSettingsLabel: String {
        manager.accountStatus == .noAccount ? "Open iCloud Settings" : "Open Settings"
    }

    private var recoveryTips: [String]? {
        switch manager.accountStatus {
        case .available, .unknown:
            guard manager.lastError != nil else { return nil }
            return [
                "Check that you're on Wi-Fi or have a strong cellular signal.",
                "Open Settings → Apple ID → iCloud and make sure Metricly is on.",
                "Force-quit and reopen the app if the issue persists for more than a few minutes."
            ]
        case .noAccount:
            return [
                "Open the Settings app and sign in at the top of the screen.",
                "Make sure iCloud Drive is enabled once you're signed in."
            ]
        case .restricted, .temporarilyUnavailable:
            return [
                "Restart the device — temporary iCloud outages often clear on reboot.",
                "Confirm iCloud is enabled in Settings → Apple ID → iCloud."
            ]
        }
    }

    private func openSystemSettings() {
        Task { await appServices.openSettings() }
    }
}
