import SwiftUI

struct SettingsICloudSyncSection: View {
    @Environment(\.appServices) private var appServices

    var body: some View {
        Section {
            CloudSyncStatusRow(manager: appServices.syncStatus)
        } header: {
            Text("iCloud Sync")
        } footer: {
            Text("Your workout data syncs automatically across devices signed in to the same iCloud account.")
        }
    }
}
