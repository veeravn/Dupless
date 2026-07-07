import SwiftUI
import SwiftData
import AppTrackingTransparency
import GoogleMobileAds

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
                .task { await startAds() }
        }
        .modelContainer(SharedStore.container)
    }

    /// Requests App Tracking Transparency (needed before the advertising
    /// identifier can be used for personalized ads), starts the ad SDK, and
    /// preloads the first interstitial. Ads still show non-personalized if the
    /// user declines tracking.
    private func startAds() async {
        _ = await ATTrackingManager.requestTrackingAuthorization()
        await MobileAds.shared.start()
        ads.preload()
    }
}
