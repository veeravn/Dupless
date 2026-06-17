import SwiftUI

/// Permission-priming screen shown before/after requesting Photos access.
/// Step 2 of the primary flow: "App explains local photo analysis."
struct PhotoAccessView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "photo.stack")
                .font(.system(size: 64))
                .foregroundStyle(.tint)

            VStack(spacing: 12) {
                Text("Find duplicates, privately")
                    .font(.title.bold())
                    .multilineTextAlignment(.center)

                Text("CleanShots analyzes your photos right on this device to find duplicates and similar shots. Your photos are never uploaded.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)

            Spacer()

            VStack(spacing: 12) {
                Button(action: requestAccess) {
                    Text(primaryButtonTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                if isDenied {
                    Button("Open Settings") { openSettings() }
                        .font(.subheadline)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }

    private var isDenied: Bool {
        authorization.status == .denied || authorization.status == .restricted
    }

    private var primaryButtonTitle: String {
        isDenied ? "Photos Access Needed" : "Continue"
    }

    private func requestAccess() {
        if isDenied {
            openSettings()
        } else {
            Task { await authorization.requestAccess() }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
