import SwiftUI
import SwiftData

/// Settings row group for the Strava integration. Connected state shows the
/// athlete's name, a disconnect action, the auto-share toggle, and a
/// sync-from-Strava button to backfill historical activities.
/// Disconnected state shows a single Connect button.
///
/// The auto-share preference is persisted via `@AppStorage` rather than
/// `UserSettings` so it can be read from the cardio-finish flow without a
/// SwiftData fetch in the hot path.
struct StravaSettingsSection: View {
    @StateObject private var service = StravaService.shared
    @AppStorage("strava.autoShareCardio") private var autoShareCardio: Bool = true
    @State private var showingDisconnectConfirm = false
    @State private var isSyncing = false
    @State private var lastSyncResult: StravaImportService.Result?
    @Environment(\.modelContext) private var modelContext
    @Query private var existingSessions: [CardioSession]

    var body: some View {
        Section {
            if service.isConnected {
                connectedRow
                Toggle(isOn: $autoShareCardio) {
                    HStack(spacing: 12) {
                        settingsIcon("arrow.up.forward.circle.fill", color: .orange)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(String(localized: "Auto-share new cardio",
                                        comment: "Settings row title for the auto-share-to-Strava toggle"))
                            Text(String(localized: "Pushes each completed run, ride, or walk to Strava.",
                                        comment: "Settings row subtitle under Auto-share new cardio"))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                syncFromStravaRow
                Button(role: .destructive) {
                    showingDisconnectConfirm = true
                } label: {
                    HStack(spacing: 12) {
                        settingsIcon("xmark.circle.fill", color: .red)
                        Text(String(localized: "Disconnect from Strava",
                                    comment: "Destructive settings button to unlink the Strava account"))
                    }
                }
            } else {
                connectButton
            }

            if let err = service.lastError {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: "figure.run.circle.fill")
                    .foregroundStyle(.orange)
                Text(String(localized: "Strava",
                            comment: "Section header for the Strava integration settings"))
            }
        } footer: {
            if service.isConnected {
                Text(String(localized: "Strength workouts stay on Metricly — only cardio sessions get pushed to Strava.",
                            comment: "Footer text under the Strava section when connected"))
            } else {
                // The two-step hint exists because Strava's mobile sign-in
                // page doesn't honour the OAuth redirect_uri after a fresh
                // login — it drops you on their home feed. Coming back to
                // Connect a second time finds an existing session and goes
                // straight to the Authorize step.
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "Connect your Strava account to share completed cardio sessions automatically.",
                                comment: "Footer text inviting the user to connect Strava"))
                    Text(String(localized: "First time? If Strava asks you to sign in, finish that step, then come back here and tap Connect again.",
                                comment: "Footer hint explaining the Strava two-step OAuth flow"))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            String(localized: "Disconnect from Strava?",
                   comment: "Confirmation dialog title shown before unlinking Strava"),
            isPresented: $showingDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "Disconnect",
                          comment: "Destructive confirm button to unlink Strava"),
                   role: .destructive) {
                Task { await service.disconnect() }
            }
            Button(String(localized: "Cancel",
                          comment: "Cancel button on the Strava disconnect dialog"),
                   role: .cancel) {}
        } message: {
            Text(String(localized: "New cardio sessions will stop pushing to Strava. Your existing Strava data is unaffected.",
                        comment: "Message under the Strava disconnect confirmation"))
        }
    }

    // MARK: - Connected row

    private var connectedRow: some View {
        HStack(spacing: 12) {
            settingsIcon("checkmark.circle.fill", color: .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(String(localized: "Connected",
                            comment: "Status label shown when Strava is currently linked"))
                    .font(.subheadline.weight(.semibold))
                if let name = service.athleteDisplayName {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: "figure.run")
                .font(.caption.bold())
                .foregroundStyle(.orange)
        }
    }

    // MARK: - Sync-from-Strava

    private var syncFromStravaRow: some View {
        Button {
            Task { await runSync() }
        } label: {
            HStack(spacing: 12) {
                settingsIcon("arrow.down.circle.fill", color: .blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(String(localized: "Sync from Strava",
                                comment: "Settings row that pulls Strava activities into Metricly"))
                        .foregroundStyle(.primary)
                    Text(syncSubtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if isSyncing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.down.right.square")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .disabled(isSyncing)
        .accessibilityHint("Imports your recent Strava activities as cardio sessions.")
    }

    private var syncSubtitle: String {
        if isSyncing { return "Importing…" }
        if let r = lastSyncResult {
            let imported  = r.imported == 1 ? "1 new session" : "\(r.imported) new sessions"
            let skipped   = r.skippedExisting > 0 ? " · \(r.skippedExisting) already had" : ""
            let unsup     = r.unsupportedType > 0 ? " · \(r.unsupportedType) unsupported type\(r.unsupportedType == 1 ? "" : "s")" : ""
            return "\(imported)\(skipped)\(unsup)"
        }
        return "Pull your recent Strava activities into Metricly."
    }

    private func runSync() async {
        isSyncing = true
        defer { isSyncing = false }
        do {
            let result = try await StravaImportService.sync(
                existing: existingSessions,
                in: modelContext
            )
            lastSyncResult = result
            if result.imported == 0 && result.skippedExisting == 0 {
                AppErrorBus.shared.report(
                    message: String(localized: "Nothing new on Strava to import.", comment: "Toast when a Strava sync finds zero new and zero existing matches"),
                    kind: .info
                )
            }
        } catch {
            // All status-code branches (401 reconnect prompt, 429 rate-
            // limit, generic) live in `StravaErrorPresenter` so they're
            // unit-testable without standing up the view + bus.
            let p = StravaErrorPresenter.present(error)
            AppErrorBus.shared.report(message: p.message, kind: p.kind)
        }
    }

    // MARK: - Connect button

    private var connectButton: some View {
        Button {
            Task { await service.connect() }
        } label: {
            HStack(spacing: 12) {
                settingsIcon("figure.run.circle.fill", color: .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "Connect to Strava",
                                comment: "Settings row title for the OAuth connect button"))
                        .foregroundStyle(.primary)
                    Text(String(localized: "Auto-share completed cardio sessions.",
                                comment: "Settings row subtitle under Connect to Strava"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if service.isAuthorizing {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption.bold())
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .disabled(service.isAuthorizing)
    }

    // MARK: - Helpers

    private func settingsIcon(_ name: String, color: Color) -> some View {
        // Matches SettingsView.settingsIcon so the Strava rows are visually
        // identical to the rest of Settings (was 28×28 / radius 7 / 13pt).
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(LinearGradient(
                    colors: [color, color.opacity(0.72)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 30, height: 30)
                .shadow(color: color.opacity(0.40), radius: 4, y: 2)
            Image(systemName: name)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}
