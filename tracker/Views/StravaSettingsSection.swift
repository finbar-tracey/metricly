import SwiftUI

/// Settings row group for the Strava integration. Connected state shows the
/// athlete's name, a disconnect action, and the auto-share toggle.
/// Disconnected state shows a single Connect button.
///
/// The auto-share preference is persisted via `@AppStorage` rather than
/// `UserSettings` so it can be read from the cardio-finish flow without a
/// SwiftData fetch in the hot path.
struct StravaSettingsSection: View {
    @StateObject private var service = StravaService.shared
    @AppStorage("strava.autoShareCardio") private var autoShareCardio: Bool = true
    @State private var showingDisconnectConfirm = false

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
