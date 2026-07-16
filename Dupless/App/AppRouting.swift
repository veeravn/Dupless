import SwiftUI

/// A fully-specified scan request (used to start a scan from an intent).
struct ScanRequest: Hashable, Sendable {
    var scope: ScanScope
    var options: ScanOptions
    var sensitivity: SimilaritySensitivity
}

/// User choices for a drone/burst scan, set on the setup screen.
struct DroneBurstOptions: Hashable, Sendable {
    /// When on, meaningfully different angles (altitude, vantage, framing) are
    /// protected from cleanup. Off treats a session as pure duplicates.
    var preserveUniqueAngles: Bool = true

    static let `default` = DroneBurstOptions()
}

/// Navigation destinations the app can be driven to — by the user or by an
/// App Intent / Siri.
enum AppRoute: Hashable {
    case scanSetup
    case scan(ScanRequest)
    case droneBurstSetup
    case droneBurstScan(scope: ScanScope, options: ScanOptions, droneOptions: DroneBurstOptions)
    case review
    case resume
    case browse
    case settings
}

/// Bridges App Intents to in-app navigation. An intent sets `route`; the root
/// view observes it, navigates, and clears it. Main-actor isolated and shared.
@MainActor
@Observable
final class IntentRouter {
    static let shared = IntentRouter()
    var route: AppRoute?

    private init() {}

    func request(_ route: AppRoute) {
        self.route = route
    }
}

/// Lightweight app preferences shared between the UI and intents.
enum AppSettings {
    private static let defaultModeKey = "defaultDedupeMode"
    private static let locationMatchingKey = "locationMatchingEnabled"
    static let protectLivePhotosKey = "protectLivePhotos"
    static let includeScreenshotsKey = "includeScreenshots"
    static let excludeFavoritesKey = "excludeFavorites"
    static let skipDeleteConfirmationKey = "skipDeleteConfirmation"

    static var defaultSensitivity: SimilaritySensitivity {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultModeKey) ?? ""
            return SimilaritySensitivity(rawValue: raw) ?? .balanced
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultModeKey) }
    }

    /// Opt-in: match AI place queries (e.g. "Mall of America") by reverse-
    /// geocoding photo locations. Off by default because it sends coordinates to
    /// Apple's geocoding service — a network call, unlike the rest of the app.
    static var locationMatchingEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: locationMatchingKey) }
        set { UserDefaults.standard.set(newValue, forKey: locationMatchingKey) }
    }

    /// Whether Live Photos are protected from cleanup (like favorites/edited, but
    /// user-toggleable). On by default; turn off to let Live Photos be selected for
    /// removal. `object(...) ?? true` so an unset value defaults to protected.
    static var protectLivePhotos: Bool {
        get { UserDefaults.standard.object(forKey: protectLivePhotosKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: protectLivePhotosKey) }
    }

    /// Whether scans include screenshots. On by default. Moved out of the
    /// per-scan setup screen into Settings.
    static var includeScreenshots: Bool {
        get { UserDefaults.standard.object(forKey: includeScreenshotsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: includeScreenshotsKey) }
    }

    /// Whether favorites are excluded from scans. On by default. Moved out of
    /// the per-scan setup screen into Settings.
    static var excludeFavorites: Bool {
        get { UserDefaults.standard.object(forKey: excludeFavoritesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: excludeFavoritesKey) }
    }

    /// When on, the "Move to Recently Deleted" confirmation sheet is skipped —
    /// cleanup goes straight to PhotoKit's own system confirmation. Off by
    /// default so first-time users still see the explanation.
    static var skipDeleteConfirmation: Bool {
        get { UserDefaults.standard.bool(forKey: skipDeleteConfirmationKey) }
        set { UserDefaults.standard.set(newValue, forKey: skipDeleteConfirmationKey) }
    }

    /// The active protection policy: all hard protections on, with Live Photo
    /// protection following the user's `protectLivePhotos` setting.
    static var protectionPolicy: ProtectionPolicy {
        var policy = ProtectionPolicy.default
        policy.protectLivePhotos = protectLivePhotos
        return policy
    }
}
