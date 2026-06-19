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

    static var defaultSensitivity: SimilaritySensitivity {
        get {
            let raw = UserDefaults.standard.string(forKey: defaultModeKey) ?? ""
            return SimilaritySensitivity(rawValue: raw) ?? .balanced
        }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: defaultModeKey) }
    }
}
