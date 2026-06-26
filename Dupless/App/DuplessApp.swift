import SwiftUI
import SwiftData

@main
struct DuplessApp: App {
    @State private var authorization = PhotoAuthorizationManager()
    @State private var scanEngine = ScanEngine()
    @State private var router = IntentRouter.shared
    @State private var entitlements = EntitlementStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authorization)
                .environment(scanEngine)
                .environment(router)
                .environment(entitlements)
        }
        .modelContainer(SharedStore.container)
    }
}
