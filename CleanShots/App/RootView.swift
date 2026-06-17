import SwiftUI

/// Routes between onboarding (no access yet) and the main app (access granted).
/// Refreshes authorization when the app returns to the foreground so revoked
/// permissions are reflected immediately.
struct RootView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if authorization.status.grantsAccess {
                HomeView()
            } else {
                PhotoAccessView()
            }
        }
        .animation(.default, value: authorization.status)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { authorization.refresh() }
        }
    }
}
