import Foundation

/// One entry point for turning a typed request into a resolved `ParsedScan` the
/// UI can confirm. Defaults to the Foundation Models parser (which itself falls
/// back to templates when the model is unavailable); tests inject a parser.
struct NaturalLanguageScanCoordinator {
    let parser: ScanRequestParsing

    init(parser: ScanRequestParsing = FoundationModelScanParser()) {
        self.parser = parser
    }

    /// Parses `text`, using the app's current default mode as the baseline when
    /// the request doesn't specify one.
    func parse(_ text: String) async -> ParsedScan {
        let defaultMode = DedupeModeAppEnum(sensitivity: AppSettings.defaultSensitivity)
        return await parser.parse(text, defaultMode: defaultMode)
    }
}
