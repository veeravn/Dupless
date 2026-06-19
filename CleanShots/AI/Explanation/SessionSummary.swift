import Foundation
import SwiftData

/// Tallies of a drone/burst scan's session clusters.
struct SessionStats: Equatable, Sendable {
    var clusterCount: Int
    var bestShotCount: Int
    var protectedUniqueCount: Int
    var redundantCount: Int

    static let empty = SessionStats(clusterCount: 0, bestShotCount: 0, protectedUniqueCount: 0, redundantCount: 0)
    var isEmpty: Bool { clusterCount == 0 }
}

/// Computes `SessionStats` from the persisted `SessionClusterRecord`s.
@MainActor
enum SessionStatsBuilder {
    static func make(in context: ModelContext) -> SessionStats {
        let clusters = (try? context.fetch(FetchDescriptor<SessionClusterRecord>())) ?? []
        guard !clusters.isEmpty else { return .empty }
        return SessionStats(
            clusterCount: clusters.count,
            bestShotCount: clusters.reduce(0) { $0 + $1.recommendedBestShotIds.count },
            protectedUniqueCount: clusters.reduce(0) { $0 + $1.protectedUniqueShotIds.count },
            redundantCount: clusters.reduce(0) { $0 + $1.suggestedRemovalIds.count }
        )
    }
}

/// Produces the spec's drone/burst session summary, e.g. "Found 11 sequence
/// groups. Recommended 18 best shots. Protected 7 unique angles. Suggested
/// removing 43 redundant photos." Counts come straight from the stats.
struct SessionSummaryGenerator {
    func summarize(_ stats: SessionStats) -> String {
        guard !stats.isEmpty else {
            return "No photo sessions found yet. Try a drone or burst scan first."
        }
        return [
            "Found \(stats.clusterCount) sequence \(plural("group", stats.clusterCount)).",
            "Recommended \(stats.bestShotCount) best \(plural("shot", stats.bestShotCount)).",
            "Protected \(stats.protectedUniqueCount) unique \(plural("angle", stats.protectedUniqueCount)).",
            "Suggested removing \(stats.redundantCount) redundant \(plural("photo", stats.redundantCount)).",
        ].joined(separator: " ")
    }
}
