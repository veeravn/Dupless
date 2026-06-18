import Foundation
import FoundationModels

/// Parses a natural-language request with the on-device model, then resolves it
/// through the same deterministic pieces the template parser uses
/// (`DatePhraseResolver`, mode mapping). Falls back to `TemplateScanParser` when
/// the model is unavailable or errors, so callers always get a usable result.
///
/// Privacy: only the user's typed request is sent to the model — never image
/// data — and the session is discarded after use.
struct FoundationModelScanParser: ScanRequestParsing {
    let service: FoundationModelService
    var resolver: DatePhraseResolver
    let fallback: TemplateScanParser

    init(service: FoundationModelService = FoundationModelService(),
         resolver: DatePhraseResolver = DatePhraseResolver()) {
        self.service = service
        self.resolver = resolver
        self.fallback = TemplateScanParser(resolver: resolver)
    }

    func parse(_ text: String, defaultMode: DedupeModeAppEnum) async -> ParsedScan {
        guard service.availability.isAvailable else {
            return await fallback.parse(text, defaultMode: defaultMode)
        }
        do {
            let session = service.makeSession(instructions: Self.instructions)
            let draft = try await session.respond(to: text, generating: ScanRequestDraft.self).content
            return resolve(draft, defaultMode: defaultMode)
        } catch {
            return await fallback.parse(text, defaultMode: defaultMode)
        }
    }

    private func resolve(_ draft: ScanRequestDraft, defaultMode: DedupeModeAppEnum) -> ParsedScan {
        let mode = DedupeModeAppEnum(rawValue: draft.mode)
            ?? TemplateScanParser.mode(in: draft.mode.lowercased())
            ?? defaultMode
        let phrase = DatePhrase(rawValue: draft.datePhrase)

        let target: AIScanCommand.Target
        if let phrase {
            let range = resolver.resolve(phrase)
            target = .dateRange(start: range.start, end: range.end)
        } else {
            target = .recent(limit: 300)
        }

        let command = AIScanCommand(target: target, mode: mode, includeScreenshots: draft.includeScreenshots)
        return ParsedScan(
            command: command,
            summary: ParsedScan.summary(for: command, datePhrase: phrase),
            understood: true
        )
    }

    private static let instructions = """
        You convert a photo-cleanup request into structured scan settings for an \
        on-device duplicate-photo app. Choose the closest matching options. Never \
        invent dates — only classify into the provided relative ranges. The app \
        always requires the user to review before anything is deleted.
        """
}

/// Structured output the model fills in. String fields (rather than enums) keep
/// the model forgiving; mapping to app types happens in `resolve`.
@Generable
struct ScanRequestDraft {
    @Guide(description: "Cleanup strictness. One of: conservative, balanced, aggressive, droneBurst.")
    var mode: String

    @Guide(description: "Relative date range to limit the scan, or 'none'. One of: none, today, yesterday, last_weekend, last_week, last_month, last_year.")
    var datePhrase: String

    @Guide(description: "Whether screenshots should be included in the scan.")
    var includeScreenshots: Bool
}
