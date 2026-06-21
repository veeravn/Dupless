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
            return resolve(draft, text: text, defaultMode: defaultMode)
        } catch {
            return await fallback.parse(text, defaultMode: defaultMode)
        }
    }

    private func resolve(_ draft: ScanRequestDraft, text: String, defaultMode: DedupeModeAppEnum) -> ParsedScan {
        let mode = DedupeModeAppEnum(rawValue: draft.mode)
            ?? TemplateScanParser.mode(in: draft.mode.lowercased())
            ?? defaultMode
        // Only honor a date range the user actually expressed: a vague "recent"
        // trip must not silently become "last week". Require the request to
        // contain the phrase's own keyword, else scan recent photos with no date
        // filter.
        let phrase = Self.corroboratedDatePhrase(DatePhrase(rawValue: draft.datePhrase), in: text)

        let target: AIScanCommand.Target
        if let phrase {
            let range = resolver.resolve(phrase)
            target = .dateRange(start: range.start, end: range.end)
        } else {
            target = .recent(limit: 300)
        }

        // "none"/blank means scan the whole scope; otherwise narrow by subject.
        let trimmed = draft.contentQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let contentQuery = (trimmed.isEmpty || trimmed == "none") ? nil : trimmed

        let command = AIScanCommand(
            target: target, mode: mode,
            includeScreenshots: draft.includeScreenshots, contentQuery: contentQuery
        )
        return ParsedScan(
            command: command,
            summary: ParsedScan.summary(for: command, datePhrase: phrase),
            understood: true,
            source: .appleIntelligence
        )
    }

    /// A model-chosen date phrase is honored only when the request literally
    /// contains that phrase's keyword (week/month/year/weekend/yesterday/today).
    /// This stops vague recency ("recent", "lately") from being inflated into a
    /// concrete range like last week.
    static func corroboratedDatePhrase(_ phrase: DatePhrase?, in text: String) -> DatePhrase? {
        guard let phrase else { return nil }
        let lower = text.lowercased()
        let keyword: String
        switch phrase {
        case .today: keyword = "today"
        case .yesterday: keyword = "yesterday"
        case .lastWeekend: keyword = "weekend"
        case .lastWeek: keyword = "week"
        case .lastMonth: keyword = "month"
        case .lastYear: keyword = "year"
        }
        return lower.contains(keyword) ? phrase : nil
    }

    private static let instructions = """
        You convert a photo-cleanup request into structured scan settings for an \
        on-device duplicate-photo app. Choose the closest matching options. Only \
        set a date range when the request explicitly names a time period such as \
        'yesterday', 'last weekend', or 'last month'. Treat vague words like \
        'recent', 'recently', or 'lately' as no date range ('none') and capture \
        the subject instead. Never invent dates. For the subject, use only a \
        generic visual category an image classifier could recognize (e.g. \
        'beach', 'mall', 'wedding') — not a specific place or person name. The \
        app always requires the user to review before anything is deleted.
        """
}

/// Structured output the model fills in. String fields (rather than enums) keep
/// the model forgiving; mapping to app types happens in `resolve`.
@Generable
struct ScanRequestDraft {
    @Guide(description: "Cleanup strictness. One of: conservative, balanced, aggressive, droneBurst.")
    var mode: String

    @Guide(description: "Relative date range to limit the scan — ONLY if the user explicitly names one. Use 'none' for no date and for vague words like 'recent', 'recently', or 'lately'. One of: none, today, yesterday, last_weekend, last_week, last_month, last_year.")
    var datePhrase: String

    @Guide(description: "Whether screenshots should be included in the scan.")
    var includeScreenshots: Bool

    @Guide(description: "A single GENERIC VISUAL subject to narrow the scan to, like 'birthday', 'beach', 'dog', 'food', or 'mall'. An on-device image classifier matches this, and it only recognizes visual categories — NOT specific place names, landmarks, events, or people. If the request names a specific place/event/person, reduce it to its general visual category if one is obvious (e.g. 'Mall of America' -> 'mall', 'Sarah's wedding' -> 'wedding'); otherwise use 'none'.")
    var contentQuery: String
}
