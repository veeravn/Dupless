import Foundation

/// Non-LLM keeper explanation — reuses the MVP 2 wording. Used as the fallback
/// and as the unit-tested reference for the model implementation.
struct TemplateRecommendationExplainer: RecommendationExplaining {
    func explainKeeper(_ input: KeeperExplanationInput) async -> String {
        RecommendationText.keeperSummary(badges: input.keeperBadges)
    }
}

/// Non-LLM cleanup summary, matching the spec's phrasing. Counts come straight
/// from `CleanupStats`, so it never overstates results.
struct TemplateCleanupSummaryGenerator: CleanupSummaryGenerating {
    func summarize(_ stats: CleanupStats) async -> String {
        guard !stats.isEmpty else {
            return "No duplicate groups yet. Try running a scan first."
        }
        var sentences: [String] = []
        sentences.append("I found \(stats.groupCount) similar-photo \(plural("group", stats.groupCount)).")
        sentences.append("I recommend reviewing \(stats.reviewableCount) \(plural("photo", stats.reviewableCount)) for cleanup.")
        if let protectedClause = protectionClause(stats) {
            sentences.append(protectedClause)
        }
        return sentences.joined(separator: " ")
    }

    private func protectionClause(_ stats: CleanupStats) -> String? {
        var parts: [String] = []
        if stats.protectedFavorites > 0 {
            parts.append("\(stats.protectedFavorites) \(plural("favorite", stats.protectedFavorites))")
        }
        if stats.protectedLivePhotos > 0 {
            parts.append("\(stats.protectedLivePhotos) Live \(plural("Photo", stats.protectedLivePhotos))")
        }
        if stats.protectedPeople > 0 {
            parts.append("\(stats.protectedPeople) \(plural("photo", stats.protectedPeople)) with people")
        }
        guard !parts.isEmpty else { return nil }
        return "I protected " + grammaticalJoin(parts) + "."
    }

    private func grammaticalJoin(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default: return parts.dropLast().joined(separator: ", ") + ", and " + parts[parts.count - 1]
        }
    }
}
