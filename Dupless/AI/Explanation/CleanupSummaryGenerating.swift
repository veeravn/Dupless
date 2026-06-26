import Foundation
import SwiftData

/// Structured counts that summarize a scan's results. Image-free — just tallies.
struct CleanupStats: Equatable, Sendable {
    var groupCount: Int
    /// Photos suggested for removal across all groups.
    var reviewableCount: Int
    var protectedFavorites: Int
    var protectedLivePhotos: Int
    var protectedPeople: Int

    static let empty = CleanupStats(groupCount: 0, reviewableCount: 0,
                                    protectedFavorites: 0, protectedLivePhotos: 0, protectedPeople: 0)

    var isEmpty: Bool { groupCount == 0 }
}

/// Produces a friendly summary of a scan from structured `CleanupStats`. Template
/// impl uses fixed phrasing; the Foundation Models impl rephrases conversationally.
protocol CleanupSummaryGenerating: Sendable {
    func summarize(_ stats: CleanupStats) async -> String
}

/// Computes `CleanupStats` from the persisted groups and cached protection flags.
/// Pure over a `ModelContext`.
@MainActor
enum CleanupStatsBuilder {
    static func make(in context: ModelContext) -> CleanupStats {
        let ranked = GroupRankingResolver.rankedGroups(in: context)
        guard !ranked.isEmpty else { return .empty }

        let reviewable = ranked.reduce(0) { $0 + $1.ranking.suggestedRemovalIdentifiers.count }
        let protectedIDs = Set(ranked.flatMap { $0.ranking.protectedIdentifiers })
        let flags = cachedFlags(for: protectedIDs, in: context)

        var favorites = 0, live = 0, people = 0
        for id in protectedIDs {
            guard let f = flags[id] else { continue }
            if f.isFavorite { favorites += 1 }
            if f.isLivePhoto { live += 1 }
            if f.personDetected { people += 1 }
        }

        return CleanupStats(
            groupCount: ranked.count,
            reviewableCount: reviewable,
            protectedFavorites: favorites,
            protectedLivePhotos: live,
            protectedPeople: people
        )
    }

    private static func cachedFlags(for ids: Set<String>, in context: ModelContext) -> [String: PhotoFlags] {
        guard !ids.isEmpty else { return [:] }
        let records = (try? context.fetch(
            FetchDescriptor<ImageFeatureRecord>(predicate: #Predicate { ids.contains($0.assetLocalIdentifier) })
        )) ?? []
        return Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalIdentifier, $0.cachedAnalysis.flags) })
    }
}
