import SwiftUI
import SwiftData

@main
struct DuplessApp: App {
    @State private var authorization = PhotoAuthorizationManager()
    @State private var scanEngine = ScanEngine()
    @State private var router = IntentRouter.shared
    @State private var ads = InterstitialAdManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authorization)
                .environment(scanEngine)
                .environment(router)
                .environment(ads)
        }
        .modelContainer(SharedStore.container)
    }
}
