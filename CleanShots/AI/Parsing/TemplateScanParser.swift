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

        // Deterministic content/place scoping, so these work on devices without
        // Apple Intelligence (where this parser is the real one, not just a test
        // reference). Mirrors what the model fills into contentQuery/locationQuery.
        let (contentQuery, locationQuery) = Self.scope(in: lower)

        let target: AIScanCommand.Target
        if let phrase {
            let range = resolver.resolve(phrase)
            target = .dateRange(start: range.start, end: range.end)
        } else {
            // An undated place query reaches further back, mirroring the model
            // parser: location is a post-fetch filter, so the candidate window
            // must be deep enough to contain the trip.
            let limit = locationQuery == nil
                ? AIScanCommand.defaultRecentLimit
                : AIScanCommand.placeScopedRecentLimit
            target = .recent(limit: limit)
        }

        let command = AIScanCommand(
            target: target, mode: mode, includeScreenshots: includeScreenshots,
            contentQuery: contentQuery, locationQuery: locationQuery
        )
        // "Understood" if we recognized any concrete signal beyond bare defaults.
        let understood = phrase != nil || Self.mode(in: lower) != nil
            || Self.excludesScreenshots(in: lower)
            || contentQuery != nil || locationQuery != nil
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

    // MARK: - Content / location scoping

    /// Generic visual subjects the on-device image classifier reliably
    /// recognizes. Deliberately small and high-precision: a wrong `contentQuery`
    /// silently filters a scan down to nothing, so the parser only sets one when
    /// a known category word is named. Anything else is treated as a place.
    static let visualSubjects: Set<String> = [
        "beach", "ocean", "lake", "river", "waterfall", "mountain", "mountains",
        "forest", "desert", "snow", "sunset", "sunrise", "sky", "landscape",
        "food", "meal", "coffee", "cake", "dessert", "drink",
        "dog", "dogs", "cat", "cats", "pet", "pets", "bird", "horse", "fish",
        "flower", "flowers", "tree", "trees", "garden", "plant", "plants",
        "car", "cars", "boat", "bike", "motorcycle", "plane", "train",
        "baby", "wedding", "birthday", "party", "concert", "graduation",
        "fireworks", "selfie", "selfies", "portrait", "art", "painting", "tattoo"
    ]

    /// Verbs and object nouns that mark text as an actual scan request. Without
    /// one of these the parser doesn't read a subject, so bare gibberish
    /// ("hello there") stays "not understood" instead of being read as a place.
    private static let scanVerbs: Set<String> = [
        "scan", "find", "search", "look", "show", "get", "clean", "cleanup",
        "review", "dedupe", "deduplicate", "remove", "delete", "check", "see",
        "compare", "organize", "sort", "identify", "detect", "gather", "do", "pull", "grab"
    ]
    private static let objectNouns: Set<String> = [
        "photo", "photos", "picture", "pictures", "pic", "pics", "image", "images",
        "shot", "shots", "duplicate", "duplicates", "dupe", "dupes",
        "screenshot", "screenshots"
    ]

    /// Framing words removed before reading the subject: the scan verbs and
    /// object nouns above, plus articles, prepositions, recency/date words, mode
    /// synonyms, and screenshot terms (each handled by its own detector).
    private static let stopWords: Set<String> = scanVerbs.union(objectNouns).union([
        "my", "the", "a", "an", "some", "any", "all", "me", "for", "of", "and",
        "from", "in", "at", "to", "on", "with", "that", "those", "these", "is",
        "be", "but", "up", "about", "please", "can", "could", "would", "you", "i",
        "we", "us", "give", "want", "need", "help", "similar", "trip", "trips",
        "everything", "anything", "stuff", "things", "thing", "only", "just",
        "also", "into", "over",
        "recent", "recently", "lately", "last", "past", "this", "day", "days",
        "week", "weeks", "weekend", "month", "months", "year", "years",
        "yesterday", "today",
        "conservative", "conservatively", "careful", "carefully", "safe", "safely",
        "aggressive", "aggressively", "thorough", "thoroughly", "loose", "loosely",
        "balanced", "drone", "burst", "mode",
        "without", "no", "skip", "exclude", "not", "including", "include"
    ])

    /// Reads an optional content theme and/or place from a framed scan request.
    /// A subject made entirely of known visual categories becomes `contentQuery`;
    /// anything else is treated as a place for the opt-in location match.
    static func scope(in lower: String) -> (content: String?, location: String?) {
        let rawTokens = lower.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        guard rawTokens.contains(where: { scanVerbs.contains($0) || objectNouns.contains($0) }) else {
            return (nil, nil)
        }
        let subject = rawTokens.filter { token in
            token.count >= 2 && token.contains(where: \.isLetter) && !stopWords.contains(token)
        }
        guard !subject.isEmpty else { return (nil, nil) }
        if subject.allSatisfy({ visualSubjects.contains($0) }) {
            return (subject.joined(separator: " "), nil)
        }
        return (nil, subject.joined(separator: " "))
    }
}
