import Foundation
import SwiftData

/// Read-only helpers that summarize scan results for Siri/Shortcuts. Pure over a
/// `ModelContext`, so they're unit-testable with an in-memory store.
@MainActor
enum CleanupSummary {
    static func text(in context: ModelContext) -> String {
        let groups = (try? context.fetch(FetchDescriptor<DuplicateGroupRecord>())) ?? []
        guard !groups.isEmpty else {
            return "No duplicate groups yet. Try running a scan first."
        }
        let removable = groups.reduce(0) { $0 + $1.estimatedRemovableCount }
        return "Your last scan found \(groups.count) \(pluralize("group", groups.count)) "
            + "with about \(removable) \(pluralize("photo", removable)) you can review."
    }

    private static func pluralize(_ word: String, _ count: Int) -> String {
        count == 1 ? word : word + "s"
    }
}

/// Collects the recommended keepers across all groups (for a best-shots album).
@MainActor
enum BestShotsCollector {
    static func keeperIdentifiers(in context: ModelContext) -> [String] {
        let groups = (try? context.fetch(FetchDescriptor<DuplicateGroupRecord>())) ?? []
        return groups.compactMap { $0.recommendedKeeperIdentifier }
    }
}

/// Produces a template explanation for the keeper of the highest-confidence
/// group (re-ranking from cached analyses).
@MainActor
enum KeeperExplanation {
    static func forTopGroup(in context: ModelContext) -> String? {
        var descriptor = FetchDescriptor<DuplicateGroupRecord>(
            sortBy: [SortDescriptor(\.confidence, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let group = (try? context.fetch(descriptor))?.first,
              let keeperID = group.recommendedKeeperIdentifier else { return nil }

        let wanted = Set(group.memberIdentifiers)
        let records = (try? context.fetch(
            FetchDescriptor<ImageFeatureRecord>(predicate: #Predicate { wanted.contains($0.assetLocalIdentifier) })
        )) ?? []
        let cached = Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalIdentifier, $0.cachedAnalysis) })
        let rankables = group.memberIdentifiers.compactMap { cached[$0]?.rankablePhoto }
        let ranking = BestShotRanker().rank(rankables)
        let badges = ranking.badges[keeperID] ?? []
        return RecommendationText.keeperSummary(badges: badges)
    }
}
