import Foundation
import SwiftData

/// Structured, image-free input for explaining a keeper. Carries only quality
/// badges and confidence — never pixels — so an explanation can't overstate
/// certainty beyond what the scores support (the spec's privacy + grounding rule).
struct KeeperExplanationInput: Equatable, Sendable {
    /// Group match confidence, 0...1.
    var confidence: Double
    /// Badges earned by the recommended keeper.
    var keeperBadges: [QualityBadge]
    /// Notable downsides of the photos suggested for removal (e.g. blurry,
    /// lower resolution) so the explanation can contrast them.
    var removalBadges: [QualityBadge]
}

/// Explains why a photo was recommended as the keeper. The template impl wraps
/// the MVP 2 wording; the Foundation Models impl rephrases conversationally,
/// grounded only in the structured input.
protocol RecommendationExplaining: Sendable {
    func explainKeeper(_ input: KeeperExplanationInput) async -> String
}

/// Builds a `KeeperExplanationInput` from cached analyses for a group. Pure over
/// a `ModelContext`; no PhotoKit, no image data.
@MainActor
enum KeeperExplanationInputBuilder {
    static func make(for group: DuplicateGroupRecord, in context: ModelContext) -> KeeperExplanationInput? {
        let ranking = GroupRankingResolver.ranking(for: group, in: context)
        guard let keeperID = ranking.keeperIdentifier else { return nil }
        let removalBadges = ranking.suggestedRemovalIdentifiers
            .flatMap { ranking.badges[$0] ?? [] }
            .filter(\.isNegative)
        return KeeperExplanationInput(
            confidence: group.confidence,
            keeperBadges: ranking.badges[keeperID] ?? [],
            removalBadges: Array(Set(removalBadges))
        )
    }

    static func forTopGroup(in context: ModelContext) -> KeeperExplanationInput? {
        var descriptor = FetchDescriptor<DuplicateGroupRecord>(
            sortBy: [SortDescriptor(\.confidence, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let group = (try? context.fetch(descriptor))?.first else { return nil }
        return make(for: group, in: context)
    }
}
