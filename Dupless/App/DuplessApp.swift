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
        // Registered test device: this device is served TEST ads in ALL builds
        // (incl. Release/TestFlight), so tapping an ad here never counts as
        // invalid activity. Only affects this device — real users get real ads.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["b3daf64a8372fa8c15c4602e8da882d6"]
        await MobileAds.shared.start()
        ads.preload()
    }
}
