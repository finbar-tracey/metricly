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
                            Text("Auto-share new cardio")
                            Text("Pushes each completed run, ride, or walk to Strava.")
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
                        Text("Disconnect from Strava")
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
                Text("Strava")
            }
        } footer: {
            if service.isConnected {
                Text("Strength workouts stay on Metricly — only cardio sessions get pushed to Strava.")
            } else {
                // The two-step hint exists because Strava's mobile sign-in
                // page doesn't honour the OAuth redirect_uri after a fresh
                // login — it drops you on their home feed. Coming back to
                // Connect a second time finds an existing session and goes
                // straight to the Authorize step.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connect your Strava account to share completed cardio sessions automatically.")
                    Text("First time? If Strava asks you to sign in, finish that step, then come back here and tap Connect again.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .confirmationDialog(
            "Disconnect from Strava?",
            isPresented: $showingDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                Task { await service.disconnect() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("New cardio sessions will stop pushing to Strava. Your existing Strava data is unaffected.")
        }
    }

    // MARK: - Connected row

    private var connectedRow: some View {
        HStack(spacing: 12) {
            settingsIcon("checkmark.circle.fill", color: .green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Connected")
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
                    Text("Sync from Strava")
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
        } catch StravaError.httpFailure(let status, _) where status == 401 {
            // Tokens issued before the activity:read_all scope bump don't
            // have permission to read the user's activity list — Strava
            // returns 401 on the first sync attempt. Send the user to
            // disconnect+reconnect rather than letting them retry endlessly.
            AppErrorBus.shared.report(
                message: String(localized: "Reconnect Strava to enable sync — your existing connection was created before this feature shipped.", comment: "Shown when Strava returns 401 (token missing the read scope)"),
                kind: .warning
            )
        } catch StravaError.httpFailure(let status, _) where status == 429 {
            // Strava enforces per-15-min and per-day quotas. Hitting 429
            // means the user (or our retry loop) burned through them.
            AppErrorBus.shared.report(
                message: String(localized: "Strava is rate-limiting us — try again in 15 minutes.", comment: "Shown when Strava returns 429 (rate limit)"),
                kind: .warning
            )
        } catch {
            AppErrorBus.shared.report(
                message: String(localized: "Strava sync failed — check your connection and try again.", comment: "Generic Strava sync failure"),
                kind: .failure
            )
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
                    Text("Connect to Strava")
                        .foregroundStyle(.primary)
                    Text("Auto-share completed cardio sessions.")
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
        ZStack {
            RoundedRectangle(cornerRadius: 7)
                .fill(color.gradient)
                .frame(width: 28, height: 28)
            Image(systemName: name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
