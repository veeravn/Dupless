import Foundation
import SwiftData

/// Re-ranks a duplicate group from its cached per-asset analyses. Shared by the
/// read tools (details, cleanup plan, explanation) so they all use the same
/// best-shot logic as the review UI. Pure over a `ModelContext`; no PhotoKit.
@MainActor
enum GroupRankingResolver {
    static func ranking(for group: DuplicateGroupRecord, in context: ModelContext) -> GroupRanking {
        let wanted = Set(group.memberIdentifiers)
        let records = (try? context.fetch(
            FetchDescriptor<ImageFeatureRecord>(predicate: #Predicate { wanted.contains($0.assetLocalIdentifier) })
        )) ?? []
        let cached = Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalIdentifier, $0.cachedAnalysis) })
        let rankables = group.memberIdentifiers.compactMap { cached[$0]?.rankablePhoto }
        return BestShotRanker().rank(rankables)
    }

    /// All groups paired with their rankings, highest-confidence first.
    static func rankedGroups(in context: ModelContext) -> [(group: DuplicateGroupRecord, ranking: GroupRanking)] {
        let groups = (try? context.fetch(
            FetchDescriptor<DuplicateGroupRecord>(sortBy: [SortDescriptor(\.confidence, order: .reverse)])
        )) ?? []
        return groups.map { ($0, ranking(for: $0, in: context)) }
    }
}
