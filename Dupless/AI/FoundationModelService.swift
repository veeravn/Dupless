import Foundation
import FoundationModels

/// Real backend for the AI layer, wrapping Apple's on-device Foundation Models.
///
/// This is the *only* file that imports `FoundationModels`. Everything else in
/// the AI layer depends on `AIModelProviding`, so the rest of MVP 4 stays
/// testable without a model and degrades to template behavior when the model is
/// unavailable (see `AIAvailability`).
///
/// Privacy: callers pass only structured metadata and scores into prompts —
/// never raw image data — and sessions are not persisted beyond their use.
struct FoundationModelService: AIModelProviding {
    private let model = SystemLanguageModel.default

    var availability: AIAvailability {
        switch model.availability {
        case .available:
            return .available
        case .unavailable(let reason):
            return .unavailable(reason: Self.describe(reason))
        @unknown default:
            return .unavailable(reason: "Unknown model availability.")
        }
    }

    /// Opens a fresh session with the given instructions. The caller drives
    /// structured (`@Generable`) responses or tool calls on it.
    func makeSession(instructions: String) -> LanguageModelSession {
        LanguageModelSession(model: model, instructions: instructions)
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to use AI features."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "Foundation Models is unavailable right now."
        }
    }
}
