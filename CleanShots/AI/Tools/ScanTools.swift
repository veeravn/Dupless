import Foundation
import SwiftData

/// Starts a scan by routing the app to it. Never deletes; the scan ends in the
/// review UI where the user makes every cleanup decision.
@MainActor
struct StartPhotoScanTool {
    static let name = AIToolName.startPhotoScan.rawValue
    let router: IntentRouter

    init(router: IntentRouter) { self.router = router }
    init() { self.init(router: .shared) }

    @discardableResult
    func run(_ command: AIScanCommand) -> AIToolResult {
        router.request(.scan(command.toScanRequest()))
        return AIToolResult(
            speech: "Starting a \(command.mode.speechName) scan. I'll open the results for you to review — nothing is deleted automatically.",
            didAct: true
        )
    }
}

/// Reports how many duplicate groups the last scan found and how many photos are
/// reviewable. Read-only; the model uses this to reason about the library.
@MainActor
struct GetDuplicateGroupsTool {
    static let name = AIToolName.getDuplicateGroups.rawValue

    struct Snapshot: Equatable, Sendable {
        let groupCount: Int
        let reviewableCount: Int
    }

    func snapshot(in context: ModelContext) -> Snapshot {
        let groups = (try? context.fetch(FetchDescriptor<DuplicateGroupRecord>())) ?? []
        let reviewable = groups.reduce(0) { $0 + $1.estimatedRemovableCount }
        return Snapshot(groupCount: groups.count, reviewableCount: reviewable)
    }

    func run(in context: ModelContext) -> AIToolResult {
        let snap = snapshot(in: context)
        guard snap.groupCount > 0 else {
            return AIToolResult(speech: "I haven't found any duplicate groups yet. Try running a scan first.")
        }
        return AIToolResult(
            speech: "Your last scan found \(snap.groupCount) \(plural("group", snap.groupCount)) "
                + "with about \(snap.reviewableCount) \(plural("photo", snap.reviewableCount)) to review."
        )
    }
}

/// Describes one group: its keeper, the recommended removals, and what's
/// protected. Read-only.
@MainActor
struct GetGroupDetailsTool {
    static let name = AIToolName.getGroupDetails.rawValue

    func run(groupID: UUID, in context: ModelContext) -> AIToolResult {
        var descriptor = FetchDescriptor<DuplicateGroupRecord>(predicate: #Predicate { $0.id == groupID })
        descriptor.fetchLimit = 1
        guard let group = (try? context.fetch(descriptor))?.first else {
            return AIToolResult(speech: "I couldn't find that group. It may have already been reviewed.")
        }
        let ranking = GroupRankingResolver.ranking(for: group, in: context)
        let removable = ranking.suggestedRemovalIdentifiers.count
        let protected = ranking.protectedIdentifiers.count
        let confidence = Int((group.confidence * 100).rounded())

        var parts = ["This is a \(confidence)% match of \(group.memberIdentifiers.count) photos."]
        if let keeperBadges = ranking.keeperIdentifier.flatMap({ ranking.badges[$0] }) {
            parts.append(RecommendationText.keeperSummary(badges: keeperBadges))
        }
        parts.append("\(removable) \(plural("photo", removable)) suggested for removal, "
            + "\(protected) protected and kept.")
        return AIToolResult(speech: parts.joined(separator: " "))
    }
}

/// Plural helper shared by the speech-producing tools.
func plural(_ word: String, _ count: Int) -> String { count == 1 ? word : word + "s" }
