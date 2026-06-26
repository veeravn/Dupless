import Foundation

/// The resolved outcome of parsing a natural-language request. The UI shows
/// `summary` for the user to confirm *before* any scan runs (the spec's key
/// mitigation against the model misunderstanding a request).
struct ParsedScan: Equatable, Sendable {
    /// Which parser produced this result, so the UI can show whether the request
    /// was interpreted by the on-device model or matched by keyword fallback.
    enum Source: Equatable, Sendable {
        case appleIntelligence
        case keywords

        /// Short, user-facing attribution for the confirmation screen.
        var label: String {
            switch self {
            case .appleIntelligence: return "Interpreted by Apple Intelligence"
            case .keywords: return "Matched by keywords"
            }
        }

        var systemImage: String {
            switch self {
            case .appleIntelligence: return "sparkles"
            case .keywords: return "text.magnifyingglass"
            }
        }
    }

    /// The resolved, ready-to-run command.
    var command: AIScanCommand
    /// One-line description of the resolved settings, e.g.
    /// "Balanced scan of photos from last weekend, including screenshots."
    var summary: String
    /// False when nothing meaningful could be parsed (caller falls back to the
    /// standard scan-setup screen).
    var understood: Bool
    /// Which parser produced this result. Defaults to keywords so the template
    /// path and existing tests don't need to set it.
    var source: Source = .keywords

    func toScanRequest() -> ScanRequest { command.toScanRequest() }
}

/// Turns a free-text request into a resolved `ParsedScan`. Implemented by the
/// Foundation Models parser (on-device) and the deterministic template parser
/// (fallback / tests).
protocol ScanRequestParsing: Sendable {
    func parse(_ text: String, defaultMode: DedupeModeAppEnum) async -> ParsedScan
}

extension ParsedScan {
    /// Builds the resolved-settings summary from a command and optional date phrase.
    static func summary(for command: AIScanCommand, datePhrase: DatePhrase?) -> String {
        // "birthday photos" when a content theme is set, otherwise just "photos".
        let noun = command.contentQuery.map { "\($0) photos" } ?? "photos"
        let scopeText: String
        switch command.target {
        case .recent(let limit):
            scopeText = "your \(limit) most recent \(noun)"
        case .album:
            scopeText = command.contentQuery != nil ? "\(noun) in the chosen album" : "the chosen album"
        case .dateRange:
            scopeText = "\(noun) from \(datePhrase?.spokenName ?? "the chosen dates")"
        }
        let place = command.locationQuery.map { " at \($0)" } ?? ""
        let screenshots = command.includeScreenshots ? "including screenshots" : "excluding screenshots"
        return "\(command.mode.speechName.capitalized) scan of \(scopeText)\(place), \(screenshots)."
    }
}
