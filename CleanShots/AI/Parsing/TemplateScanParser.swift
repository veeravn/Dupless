import Foundation

/// Deterministic keyword parser used when Foundation Models is unavailable, and
/// as the unit-tested reference for parsing behavior. No model, no network —
/// pure string matching plus `DatePhraseResolver` for the calendar math.
struct TemplateScanParser: ScanRequestParsing {
    var resolver: DatePhraseResolver

    init(resolver: DatePhraseResolver = DatePhraseResolver()) {
        self.resolver = resolver
    }

    func parse(_ text: String, defaultMode: DedupeModeAppEnum) async -> ParsedScan {
        let lower = text.lowercased()

        let mode = Self.mode(in: lower) ?? defaultMode
        let includeScreenshots = !Self.excludesScreenshots(in: lower)
        let phrase = Self.datePhrase(in: lower)

        let target: AIScanCommand.Target
        if let phrase {
            let range = resolver.resolve(phrase)
            target = .dateRange(start: range.start, end: range.end)
        } else {
            target = .recent(limit: 300)
        }

        let command = AIScanCommand(target: target, mode: mode, includeScreenshots: includeScreenshots)
        // "Understood" if we recognized any concrete signal beyond bare defaults.
        let understood = phrase != nil || Self.mode(in: lower) != nil || Self.excludesScreenshots(in: lower)
        return ParsedScan(
            command: command,
            summary: ParsedScan.summary(for: command, datePhrase: phrase),
            understood: understood
        )
    }

    // MARK: - Keyword extraction

    static func mode(in lower: String) -> DedupeModeAppEnum? {
        if lower.contains("conservative") || lower.contains("careful") || lower.contains("safe") {
            return .conservative
        }
        if lower.contains("aggressive") || lower.contains("thorough") || lower.contains("loose") {
            return .aggressive
        }
        if lower.contains("balanced") {
            return .balanced
        }
        if lower.contains("drone") || lower.contains("burst") {
            return .droneBurst
        }
        return nil
    }

    static func excludesScreenshots(in lower: String) -> Bool {
        let negatives = ["no screenshot", "without screenshot", "skip screenshot",
                         "exclude screenshot", "not screenshot", "no screenshots"]
        return negatives.contains { lower.contains($0) }
    }

    static func datePhrase(in lower: String) -> DatePhrase? {
        // Order matters: check more specific phrases before generic ones.
        if lower.contains("last weekend") || lower.contains("this past weekend") { return .lastWeekend }
        if lower.contains("last week") || lower.contains("past week") { return .lastWeek }
        if lower.contains("last month") || lower.contains("past month") { return .lastMonth }
        if lower.contains("last year") || lower.contains("past year") { return .lastYear }
        if lower.contains("yesterday") { return .yesterday }
        if lower.contains("today") { return .today }
        return nil
    }
}
