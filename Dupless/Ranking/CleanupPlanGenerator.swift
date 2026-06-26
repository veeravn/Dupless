import Foundation

/// The keeper/removal decision for one group.
struct DuplicateGroupDecision: Sendable, Equatable, Identifiable {
    let id: UUID
    let keeperIdentifier: String?
    let removalIdentifiers: [String]
    let protectedIdentifiers: [String]
}

/// A caution surfaced before cleanup.
enum CleanupWarning: Sendable, Equatable {
    /// Every non-keeper in the group is protected — nothing safe to remove.
    case allProtected(groupID: UUID)
    /// The group produced no keeper (shouldn't happen for real groups).
    case noKeeper(groupID: UUID)

    var message: String {
        switch self {
        case .allProtected: return "All similar photos in a group are protected — nothing was selected."
        case .noKeeper: return "A group had no clear keeper."
        }
    }
}

/// A structured, reviewable cleanup plan (spec's `CleanupPlan`).
struct CleanupPlan: Sendable, Equatable {
    let groups: [DuplicateGroupDecision]
    let protectedAssetIds: [String]
    let suggestedRemovalAssetIds: [String]
    let estimatedStorageSavings: Int?
    let warnings: [CleanupWarning]

    var hasRemovals: Bool { !suggestedRemovalAssetIds.isEmpty }
}

/// Builds a `CleanupPlan` from per-group rankings. Pure; no PhotoKit.
struct CleanupPlanGenerator {
    func make(
        groupRankings: [(id: UUID, ranking: GroupRanking)],
        bytesForAsset: ((String) -> Int)? = nil
    ) -> CleanupPlan {
        var decisions: [DuplicateGroupDecision] = []
        var protected: [String] = []
        var removals: [String] = []
        var warnings: [CleanupWarning] = []

        for (id, ranking) in groupRankings {
            decisions.append(
                DuplicateGroupDecision(
                    id: id,
                    keeperIdentifier: ranking.keeperIdentifier,
                    removalIdentifiers: ranking.suggestedRemovalIdentifiers,
                    protectedIdentifiers: ranking.protectedIdentifiers
                )
            )
            protected.append(contentsOf: ranking.protectedIdentifiers)
            removals.append(contentsOf: ranking.suggestedRemovalIdentifiers)

            if ranking.keeperIdentifier == nil {
                warnings.append(.noKeeper(groupID: id))
            } else if ranking.suggestedRemovalIdentifiers.isEmpty && !ranking.protectedIdentifiers.isEmpty {
                warnings.append(.allProtected(groupID: id))
            }
        }

        let savings = bytesForAsset.map { provider in
            removals.reduce(0) { $0 + provider($1) }
        }

        return CleanupPlan(
            groups: decisions,
            protectedAssetIds: Array(Set(protected)),
            suggestedRemovalAssetIds: removals,
            estimatedStorageSavings: savings,
            warnings: warnings
        )
    }
}
