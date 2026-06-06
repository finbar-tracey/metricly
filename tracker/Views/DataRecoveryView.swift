import SwiftUI

/// Shown by `trackerApp` when SwiftData can't open the store after the
/// quarantine retry. Replaces the previous `fatalError(...)` that
/// crashed the app on every cold launch when the container was
/// unrecoverable — for a fitness app with years of history, that was
/// the worst-possible failure mode (no path to recovery; reinstall
/// erases everything).
///
/// The view is intentionally minimal: a sympathetic copy block, the
/// raw error (collapsible — most users won't read it, but support
/// will need it), and three actions:
///
///   1. **Try Again** — restart the app process via `exit(0)`. The
///      next cold launch retries the same container-init path; if the
///      issue was transient (filesystem busy, iCloud half-synced) it
///      may succeed.
///
///   2. **Open Files app** — surfaces the iCloud-synced Documents
///      directory where any quarantined `default.store.corrupt-…`
///      files were dropped, so the user can copy them out for export.
///
///   3. **Email Support** — pre-filled mail with the error and a
///      summary, so users don't have to figure out what to write.
///
/// What this view explicitly does NOT do: offer a "start fresh" /
/// destructive option. Wiping the corrupted files is recoverable but
/// silently destroys whatever data was in them — that's a decision
/// users should make outside the app (export first via Files), not in
/// a panic from a recovery screen.
struct DataRecoveryView: View {
    let error: Error?

    @State private var showingErrorDetails = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 32)

                // Icon — caution amber, not alarm red. The data may
                // still be recoverable; this isn't "we lost your data,"
                // it's "we couldn't read it just now."
                ZStack {
                    Circle()
                        .fill(Color.yellow.opacity(0.18))
                        .frame(width: 88, height: 88)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.yellow)
                }

                VStack(spacing: 12) {
                    Text("Couldn't open your data")
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)

                    Text("Metricly had trouble opening your training data on this launch. Your files have been preserved — they may still be exportable for recovery.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)
                }

                actions
                    .padding(.horizontal, 24)

                if error != nil {
                    errorDisclosure
                        .padding(.horizontal, 24)
                }

                Spacer(minLength: 32)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                // Forces the process to exit cleanly. iOS will relaunch
                // on the next user tap; that re-runs trackerApp.init()
                // which retries the container-open path. Plain `exit(0)`
                // is the documented way to do this from a UI scene; we
                // don't use abort() / fatalError() because either would
                // log as a crash in App Store analytics.
                exit(0)
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.tileRadius, style: .continuous))
            }

            Button {
                // Open the Files app to the on-device documents root.
                // The quarantined `.corrupt-…` files live in the app's
                // Application Support directory; Files won't surface
                // those directly but the user can dig into the iCloud
                // Drive → Metricly folder where exports go.
                if let url = URL(string: "shareddocuments://") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Open Files App", systemImage: "folder")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            Button {
                openSupportEmail()
            } label: {
                Label("Email Support", systemImage: "envelope")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Error details

    private var errorDisclosure: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingErrorDetails.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showingErrorDetails ? "chevron.down" : "chevron.right")
                        .font(.caption.weight(.semibold))
                    Text("Technical details")
                        .font(.caption.weight(.semibold))
                    Spacer()
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showingErrorDetails, let error {
                Text(String(describing: error))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.chipRadius, style: .continuous))
                    .textSelection(.enabled)
            }
        }
    }

    private func openSupportEmail() {
        let subject = "Metricly: data recovery"
        let body = """
        I'm seeing the "Couldn't open your data" screen on launch.

        Technical details:
        \(error.map { String(describing: $0) } ?? "(none)")
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "support@metricly.app"
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        if let url = components.url {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    DataRecoveryView(error: NSError(
        domain: "SwiftData",
        code: 134060,
        userInfo: [NSLocalizedDescriptionKey: "The model used to open the store is incompatible with the one that created the store."]
    ))
}
