import SwiftUI
import SwiftData

@main
struct CleanShotsApp: App {
    @State private var authorization = PhotoAuthorizationManager()
    @State private var scanEngine = ScanEngine()
    @State private var router = IntentRouter.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authorization)
                .environment(scanEngine)
                .environment(router)
        }
        .modelContainer(SharedStore.container)
    }
}
