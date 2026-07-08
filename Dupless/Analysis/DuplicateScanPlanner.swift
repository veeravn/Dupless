import Foundation

/// Combines visual grouping (`DuplicateGrouper`) with best-shot ranking
/// (`BestShotRanker`) into the results the scan persists. Crucially, the keeper
/// is the MVP 2 *ranked* best shot, not the grouper's highest-resolution
/// placeholder. Pure and `Sendable`, so the scan engine can run it off-main and
/// it's unit-testable without PhotoKit.
struct DuplicateScanPlanner: Sendable {
    var sensitivity: SimilaritySensitivity

    func plan(_ analyses: [CachedAnalysis]) -> [ScanGroupResult] {
        let groups = DuplicateGrouper().group(analyses.map { $0.toAnalyzedPhoto() }, sensitivity: sensitivity)
        let ranker = BestShotRanker(policy: AppSettings.protectionPolicy)
        let byID = Dictionary(uniqueKeysWithValues: analyses.map { ($0.id, $0) })

        return groups.map { group in
            let rankables = group.memberIdentifiers.compactMap { byID[$0]?.rankablePhoto }
            let ranking = ranker.rank(rankables)
            return ScanGroupResult(
                memberIdentifiers: group.memberIdentifiers,
                confidence: group.confidence,
                keeperIdentifier: ranking.keeperIdentifier ?? group.keeperIdentifier
            )
        }
    }
}
