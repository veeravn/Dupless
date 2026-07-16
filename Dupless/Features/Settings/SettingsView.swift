import SwiftUI

/// App-wide scan preferences, split out of the per-scan setup screen so
/// they're set once instead of re-checked before every scan.
struct SettingsView: View {
    @AppStorage(AppSettings.includeScreenshotsKey) private var includeScreenshots = true
    @AppStorage(AppSettings.excludeFavoritesKey) private var excludeFavorites = true
    @AppStorage(AppSettings.protectLivePhotosKey) private var protectLivePhotos = true
    @AppStorage(AppSettings.skipDeleteConfirmationKey) private var skipDeleteConfirmation = false

    var body: some View {
        Form {
            Section {
                Toggle("Include screenshots", isOn: $includeScreenshots)
                Toggle("Protect favorites", isOn: $excludeFavorites)
                Toggle("Protect Live Photos", isOn: $protectLivePhotos)
            } header: {
                Text("Scan Options")
            } footer: {
                Text("Protected Live Photos are grouped but never pre-selected for removal. Turn off to allow cleaning up duplicate Live Photos.")
            }

            Section {
                Toggle("Skip delete confirmation", isOn: $skipDeleteConfirmation)
            } header: {
                Text("Cleanup")
            } footer: {
                Text("When on, tapping \"Move to Recently Deleted\" skips Dupless's confirmation and goes straight to the Photos app's own confirmation.")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
