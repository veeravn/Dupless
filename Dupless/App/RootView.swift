import SwiftUI
import StoreKit

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

// MARK: - Monetization (StoreKit 2)
//
// Dupless Pro unlocks the AI "Ask Dupless" scans and Drone/Burst mode. It's sold
// as EITHER a one-time lifetime unlock OR an annual subscription — the user picks
// on the paywall. Everything runs through StoreKit on-device (no server, nothing
// collected), so the "Data Not Collected" privacy posture is preserved.
//
// This section can later be split into its own `Monetization/` group by dragging
// the types into new files in Xcode (which updates the project file). It lives
// here for now to avoid hand-editing the explicit-reference Xcode project.

/// A feature gated behind Dupless Pro.
enum ProFeature: String, Identifiable, CaseIterable {
    case aiScan
    case droneBurst

    var id: String { rawValue }

    var title: String {
        switch self {
        case .aiScan: return "Ask Dupless"
        case .droneBurst: return "Drone & Burst Mode"
        }
    }

    var systemImage: String {
        switch self {
        case .aiScan: return "sparkles"
        case .droneBurst: return "airplane"
        }
    }

    var blurb: String {
        switch self {
        case .aiScan:
            return "Describe what to scan in plain language, and scope a scan to a place you name — powered by on-device Apple Intelligence."
        case .droneBurst:
            return "Clean up drone and burst sequences while protecting genuinely unique angles and altitudes."
        }
    }
}

/// Pure gate decision, kept separate from StoreKit so it's trivially testable.
struct ProAccess {
    let isPro: Bool
    func isLocked(_ feature: ProFeature) -> Bool { !isPro }
}

/// Owns the StoreKit 2 products and the Pro entitlement; an app-lifetime
/// singleton injected via the environment. On-device only — entitlements are
/// verified locally and nothing is sent to any server we control.
@MainActor
@Observable
final class EntitlementStore {
    enum ProductID {
        static let lifetime = "com.vnaidu.Dupless.pro.lifetime"
        static let annual = "com.vnaidu.Dupless.pro.annual"
        static let all = [lifetime, annual]
    }

    private(set) var isPro = false
    private(set) var lifetime: Product?
    private(set) var annual: Product?
    private(set) var isLoadingProducts = false
    private(set) var loadFailed = false
    private(set) var purchaseInFlight = false

    var access: ProAccess { ProAccess(isPro: isPro) }

    init() {
        listenForTransactions()
        Task { await refresh() }
    }

    func refresh() async {
        await loadProducts()
        await updateEntitlement()
    }

    func loadProducts() async {
        isLoadingProducts = true
        loadFailed = false
        defer { isLoadingProducts = false }
        do {
            let products = try await Product.products(for: ProductID.all)
            lifetime = products.first { $0.id == ProductID.lifetime }
            annual = products.first { $0.id == ProductID.annual }
            loadFailed = lifetime == nil && annual == nil
        } catch {
            loadFailed = true
        }
    }

    func updateEntitlement() async {
        var pro = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if ProductID.all.contains(transaction.productID), transaction.revocationDate == nil {
                pro = true
            }
        }
        isPro = pro
    }

    /// Returns true if the purchase completed and Pro is now active.
    @discardableResult
    func purchase(_ product: Product) async -> Bool {
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        do {
            switch try await product.purchase() {
            case .success(let verification):
                guard case .verified(let transaction) = verification else { return false }
                await transaction.finish()
                await updateEntitlement()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            return false
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await updateEntitlement()
    }

    private func listenForTransactions() {
        Task { [weak self] in
            for await update in Transaction.updates {
                guard case .verified(let transaction) = update else { continue }
                await transaction.finish()
                await self?.updateEntitlement()
            }
        }
    }
}

/// Paywall offering BOTH a lifetime unlock and an annual subscription. The caller
/// passes the feature that triggered it for context.
struct PaywallView: View {
    var highlight: ProFeature?

    @Environment(EntitlementStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    benefits
                    options
                    restoreAndLinks
                }
                .padding()
            }
            .navigationTitle("Dupless Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                if store.lifetime == nil && store.annual == nil { await store.refresh() }
            }
            .onChange(of: store.isPro) { _, isPro in
                if isPro { dismiss() }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: highlight?.systemImage ?? "crown.fill")
                .font(.system(size: 48))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text("Unlock Dupless Pro")
                .font(.title2.bold())
            Text("Everything stays on your device. No ads, no tracking — ever.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ProFeature.allCases) { feature in
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title).font(.headline)
                        Text(feature.blurb).font(.caption).foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: feature.systemImage).foregroundStyle(.tint)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var options: some View {
        if store.isLoadingProducts {
            ProgressView().padding()
        } else if store.loadFailed {
            VStack(spacing: 8) {
                Text("Couldn't load purchase options.").font(.subheadline)
                Button("Try Again") { Task { await store.refresh() } }
            }
            .padding()
        } else {
            VStack(spacing: 12) {
                if let annual = store.annual {
                    purchaseButton(annual, caption: "per year")
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
                if let lifetime = store.lifetime {
                    purchaseButton(lifetime, caption: "one-time purchase")
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                }
            }
        }
    }

    private func purchaseButton(_ product: Product, caption: String) -> some View {
        Button {
            Task { await store.purchase(product) }
        } label: {
            HStack {
                VStack(alignment: .leading) {
                    Text(product.displayName).font(.headline)
                    Text(caption).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(product.displayPrice).font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .disabled(store.purchaseInFlight)
    }

    private var restoreAndLinks: some View {
        VStack(spacing: 12) {
            Button("Restore Purchases") { Task { await store.restore() } }
                .font(.subheadline)
                .disabled(store.purchaseInFlight)
            Text("Payment is charged to your Apple Account. Subscriptions renew automatically until canceled in Settings.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 16) {
                Link("Privacy Policy", destination: URL(string: "https://veeravn.github.io/cleanshots-site/privacy-policy.html")!)
                Link("Terms (EULA)", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
            }
            .font(.caption2)
        }
    }
}

/// Shown in place of a gated feature when the user isn't Pro, with a CTA to the
/// paywall.
struct ProLockView: View {
    let feature: ProFeature
    @State private var showPaywall = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: feature.systemImage)
                .font(.system(size: 52))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            Text(feature.title).font(.title2.bold())
            Text(feature.blurb)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Label("A Dupless Pro feature", systemImage: "crown.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                showPaywall = true
            } label: {
                Text("Unlock Dupless Pro").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: 460)
        .sheet(isPresented: $showPaywall) { PaywallView(highlight: feature) }
    }
}
