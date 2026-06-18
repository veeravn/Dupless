import Foundation

/// The resolved outcome of parsing a natural-language request. The UI shows
/// `summary` for the user to confirm *before* any scan runs (the spec's key
/// mitigation against the model misunderstanding a request).
struct ParsedScan: Equatable, Sendable {
    /// The resolved, ready-to-run command.
    var command: AIScanCommand
    /// One-line description of the resolved settings, e.g.
    /// "Balanced scan of photos from last weekend, including screenshots."
    var summary: String
    /// False when nothing meaningful could be parsed (caller falls back to the
    /// standard scan-setup screen).
    var understood: Bool

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
        let scopeText: String
        switch command.target {
        case .recent(let limit):
            scopeText = "your \(limit) most recent photos"
        case .album:
            scopeText = "the chosen album"
        case .dateRange:
            scopeText = "photos from \(datePhrase?.spokenName ?? "the chosen dates")"
        }
        let screenshots = command.includeScreenshots ? "including screenshots" : "excluding screenshots"
        return "\(command.mode.speechName.capitalized) scan of \(scopeText), \(screenshots)."
    }
}
