import SwiftUI
import UIKit
import OSLog
import GoogleMobileAds

/// Routes between onboarding (no access yet) and the main app (access granted).
/// Shows a brief launch screen first so a cold start has visible feedback while
/// authorization resolves and the store warms up. Refreshes authorization when
/// the app returns to the foreground so revoked permissions are reflected.
struct RootView: View {
    @Environment(PhotoAuthorizationManager.self) private var authorization
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
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { authorization.refresh() }
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
    private var lastShown = Date.distantPast
    private var interstitial: InterstitialAd?

    /// Diagnostics — view in Xcode/Console with subsystem "Dupless", category
    /// "ads". Logs load/present outcomes only (never user content). A "no fill"
    /// load error is expected on a brand-new AdMob account until it starts serving.
    private static let log = Logger(subsystem: "Dupless", category: "ads")

    /// Loads (or reloads) an interstitial for the next opportunity.
    func preload() {
        Task { await load() }
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

    /// Presents an interstitial if one is loaded and the frequency cap allows.
    func showIfReady() {
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

    /// Anchored adaptive banner for the current screen width (fills the width, ~50pt tall).
    static var adSize: AdSize {
        currentOrientationAnchoredAdaptiveBanner(width: UIScreen.main.bounds.width)
    }

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: Self.adSize)
        banner.adUnitID = Self.adUnitID
        banner.rootViewController = Self.rootViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {}

    private static func rootViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow?.rootViewController
    }
}

