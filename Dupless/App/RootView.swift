import SwiftUI
import UIKit
import OSLog
import AppTrackingTransparency
import GoogleMobileAds

/// Routes between onboarding (no access yet) and the main app (access granted).
/// Shows a brief launch screen first so a cold start has visible feedback while
/// authorization resolves and the store warms up. Refreshes authorization when
/// the app returns to the foreground so revoked permissions are reflected.
struct RootView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization
    @Environment(InterstitialAdManager.self) private var ads
    @Environment(\.scenePhase) private var scenePhase

    @State private var isReady = false

    var body: some View {
        ZStack {
            if isReady {
                content
                    .transition(.opacity)
            } else {
                LaunchView()
                    .transition(.opacity)
            }
        }
        .task {
            // Resolve access and give the launch bar a beat to show on a cold
            // start, then reveal the main UI.
            authorization.refresh()
            try? await Task.sleep(for: .milliseconds(900))
            withAnimation(.easeOut(duration: 0.35)) { isReady = true }
            // Request App Tracking Transparency only once the app is
            // confirmed .active (not just "some time has passed") —
            // requesting it while the window isn't truly foregrounded yet
            // (e.g. concurrently with the launch screen, or immediately after
            // another system alert like the Photos prompt is still tearing
            // down) can make the system silently skip showing the prompt.
            // App Review flagged exactly this: "unable to locate the App
            // Tracking Transparency permission request" on a fresh install.
            // Must still run before any ad SDK / tracking data collection,
            // which `bootstrap()` does first.
            await waitUntilActive()
            await ads.bootstrap()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { authorization.refresh() }
        }
    }

    /// Waits, event-driven (no arbitrary timeout), until the app is actually
    /// `.active` — not just "some time has passed". A fixed short delay isn't
    /// enough: on a real device the Photos permission alert (shown moments
    /// earlier) can sit on screen for as long as the person takes to read and
    /// tap it, which keeps `applicationState` at `.inactive` the whole time.
    /// Requesting ATT while inactive makes the system silently resolve it to
    /// `.notDetermined` with no sheet ever shown — confirmed via the
    /// `bootstrap()` logging below (appState=1/inactive, resolved status=0/
    /// notDetermined, nothing on screen) after the previous fixed-delay
    /// attempt still raced the Photos alert on device.
    private func waitUntilActive() async {
        guard UIApplication.shared.applicationState != .active else { return }
        for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
            if UIApplication.shared.applicationState == .active { return }
        }
    }

    @ViewBuilder
    private var content: some View {
        Group {
            if authorization.status.grantsAccess {
                HomeView()
            } else {
                PhotoAccessView()
            }
        }
        .animation(.default, value: authorization.status)
    }
}

/// Launch screen shown briefly on cold start: app mark, name, and a progress bar
/// that fills as the app comes up.
private struct LaunchView: View {
    @State private var progress: Double = 0

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 64, weight: .semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Dupless")
                .font(.largeTitle.bold())
            Spacer()
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)
                .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Dupless, loading")
        .task {
            withAnimation(.easeInOut(duration: 0.85)) { progress = 1 }
        }
    }
}

// MARK: - Ads (Google AdMob interstitial)

/// Loads and shows an AdMob interstitial at natural breaks (after a scan
/// completes), with a frequency cap so it isn't spammy. Fails open — any load or
/// present failure is swallowed so ads never block the app. Lives here (rather
/// than a new file) to avoid hand-editing the explicit-reference Xcode project.
@MainActor
@Observable
final class InterstitialAdManager: NSObject {
    /// Interstitial ad unit ID. DEBUG builds use Google's public TEST unit (always
    /// fills with a labeled test ad, safe to tap) so the integration is verifiable
    /// from Xcode even before the AdMob account starts serving; RELEASE builds use
    /// the real unit. The AdMob App ID is in Info.plist (`GADApplicationIdentifier`).
    #if DEBUG
    private let adUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    private let adUnitID = "ca-app-pub-6546029249563930/4161316838"
    #endif

    /// Don't present more than one interstitial per this interval.
    private let minInterval: TimeInterval = 3 * 60

    /// Persisted (UserDefaults), not just in-memory — InterstitialAdManager is
    /// re-created from scratch on every app launch, so an in-memory-only
    /// `lastShown` reset to .distantPast on every relaunch, meaning the first
    /// scan after reopening the app always showed an ad regardless of how
    /// recently one was shown in a prior session. Reported as "every time I
    /// start scanning, ads show up" — literal, not just a frequency-feels-off
    /// complaint, since most real sessions are separate app opens.
    private static let lastShownKey = "interstitialLastShown"
    private var lastShown: Date {
        get { Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Self.lastShownKey)) }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: Self.lastShownKey) }
    }

    private var interstitial: InterstitialAd?

    /// Whether an interstitial has already been shown in the current "active
    /// stretch" — reset by a fresh app launch (naturally, since this is a new
    /// instance) or by the app having been backgrounded for at least
    /// `minInterval` before returning to the foreground. NOT persisted: a
    /// user doing several scan -> review -> delete -> scan cycles back to
    /// back, without ever leaving the app, sees at most one ad; stepping
    /// away and coming back later gets another. In-memory only, observed via
    /// `observeBackgrounding()`.
    private var hasShownThisStretch = false
    private var backgroundedAt: Date?

    /// Diagnostics — view in Xcode/Console with subsystem "Dupless", category
    /// "ads". Logs load/present outcomes only (never user content). A "no fill"
    /// load error is expected on a brand-new AdMob account until it starts serving.
    private static let log = Logger(subsystem: "Dupless", category: "ads")

    /// Requests App Tracking Transparency (needed before the advertising
    /// identifier can be used for personalized ads), starts the ad SDK, and
    /// preloads the first interstitial. Ads still show non-personalized if the
    /// user declines tracking. Call only once the window is key/active — see
    /// the call site in `RootView`.
    func bootstrap() async {
        Self.log.info("ATT: requesting authorization (appState=\(UIApplication.shared.applicationState.rawValue, privacy: .public))")
        let status = await ATTrackingManager.requestTrackingAuthorization()
        // Raw values: 0 notDetermined, 1 restricted, 2 denied, 3 authorized.
        // If this logs .denied (or .notDetermined) immediately with no sheet
        // visible on screen, the OS resolved it without ever presenting UI —
        // check Settings > Privacy & Security > Tracking is on and the app
        // isn't already listed there from a prior install.
        Self.log.info("ATT: resolved status=\(status.rawValue, privacy: .public)")
        // Registered test device: this device is served TEST ads in ALL builds
        // (incl. Release/TestFlight), so tapping an ad here never counts as
        // invalid activity. Only affects this device — real users get real ads.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = ["b3daf64a8372fa8c15c4602e8da882d6"]
        await MobileAds.shared.start()
        preload()
        observeBackgrounding()
    }

    /// Loads (or reloads) an interstitial for the next opportunity.
    func preload() {
        Task { await load() }
    }

    /// Fire-and-forget observers (for the lifetime of the app) that record
    /// when the app backgrounds and, on return, reset `hasShownThisStretch`
    /// if the app was away for at least `minInterval` — otherwise a quick
    /// switch to another app and back (e.g. checking a text) would count as
    /// "leaving".
    private func observeBackgrounding() {
        Task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification) {
                backgroundedAt = .now
            }
        }
        Task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                if let backgroundedAt, Date.now.timeIntervalSince(backgroundedAt) >= minInterval {
                    hasShownThisStretch = false
                }
            }
        }
    }

    private func load() async {
        do {
            let ad = try await InterstitialAd.load(with: adUnitID, request: Request())
            ad.fullScreenContentDelegate = self
            interstitial = ad
            Self.log.info("interstitial loaded")
        } catch {
            interstitial = nil // fail open; retry at the next opportunity
            Self.log.error("interstitial load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Presents an interstitial if one is loaded and both the per-stretch cap
    /// and frequency cap allow it.
    func showIfReady() {
        guard !hasShownThisStretch else {
            Self.log.info("interstitial skipped: already shown since the app was last opened/resumed")
            return
        }
        guard Date.now.timeIntervalSince(lastShown) >= minInterval else {
            Self.log.info("interstitial skipped: within frequency cap")
            return
        }
        guard let ad = interstitial else {
            Self.log.info("interstitial skipped: none loaded yet (see load failures above)")
            return
        }
        guard let root = Self.topViewController() else {
            Self.log.info("interstitial skipped: no root view controller")
            return
        }
        lastShown = .now
        hasShownThisStretch = true
        interstitial = nil
        ad.present(from: root)
        Self.log.info("interstitial presented")
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
}

extension InterstitialAdManager: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { preload() }

    func ad(_ ad: FullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        Self.log.error("interstitial present failed: \(error.localizedDescription, privacy: .public)")
        preload()
    }
}

// MARK: - Banner ad

/// A bottom-anchored AdMob adaptive banner, sized to its own height and given a
/// bar background — drop it into a screen's `.safeAreaInset(edge: .bottom)`.
struct BottomBannerAd: View {
    var body: some View {
        BannerAdView()
            .frame(height: BannerAdView.adSize.size.height)
            .frame(maxWidth: .infinity)
            .background(.bar)
    }
}

/// SwiftUI wrapper around an AdMob adaptive banner. DEBUG uses Google's test
/// banner unit (always fills, safe to tap); RELEASE uses the real one.
private struct BannerAdView: UIViewRepresentable {
    #if DEBUG
    static let adUnitID = "ca-app-pub-3940256099942544/2934735716" // Google test banner
    #else
    static let adUnitID = "ca-app-pub-6546029249563930/6636159712"
    #endif

    fileprivate static let log = Logger(subsystem: "Dupless", category: "ads")

    /// Anchored adaptive banner for the current screen width (fills the width, ~50pt tall).
    static var adSize: AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adSize)
        banner.adUnitID = Self.adUnitID
        banner.rootViewController = Self.rootViewController()
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    /// Retries a failed load after a delay. The very first `load()` (called
    /// from `makeUIView` as soon as Home appears) can race
    /// `MobileAds.shared.start()` finishing — for a returning user Home can
    /// appear before the ATT-gated startup sequence in `RootView` completes —
    /// and with no retry a race like that left the banner permanently blank.
    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            BannerAdView.log.info("banner loaded")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            BannerAdView.log.error("banner load failed: \(error.localizedDescription, privacy: .public)")
            Task {
                try? await Task.sleep(for: .seconds(30))
                bannerView.load(Request())
            }
        }
    }

    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow?.rootViewController
    }
}

