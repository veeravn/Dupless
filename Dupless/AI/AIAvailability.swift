import Foundation

/// Whether the on-device language model (Apple Foundation Models) can be used.
/// When `.unavailable`, every AI feature falls back to the MVP 2/3 template
/// behavior, so the app is fully functional with the model off.
enum AIAvailability: Equatable, Sendable {
    case available
    /// Not usable right now; `reason` is a human-readable explanation.
    case unavailable(reason: String)

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    /// A short reason when unavailable (empty when available).
    var reason: String {
        if case .unavailable(let reason) = self { return reason }
        return ""
    }
}

/// Abstraction over the language-model backend so the AI layer is testable
/// without a real model. The Foundation Models implementation lives in
/// `FoundationModelService`; tests inject a deterministic fake.
protocol AIModelProviding: Sendable {
    var availability: AIAvailability { get }
}

/// A provider that reports the model is unavailable — drives the template
/// fallback path in tests and on devices without Foundation Models.
struct UnavailableModelProvider: AIModelProviding {
    let reason: String
    init(reason: String = "Foundation Models is not available in this context.") {
        self.reason = reason
    }
    var availability: AIAvailability { .unavailable(reason: reason) }
}
