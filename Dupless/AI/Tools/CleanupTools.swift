import Foundation
import SwiftData

/// Changes the default dedupe mode conversationally (e.g. "be more
/// conservative"). Mirrors `ChangeCleanupModeIntent` but is driven by the model.
@MainActor
struct UpdateDedupeModeTool {
    static let name = AIToolName.updateDedupeMode.rawValue

    @discardableResult
    func run(mode: DedupeModeAppEnum) -> AIToolResult {
        AppSettings.defaultSensitivity = mode.sensitivity
        return AIToolResult(
            speech: "Okay, I'll use \(mode.speechName) matching for your next scan.",
            didAct: true
        )
    }
}

/// Builds a structured, reviewable cleanup plan across all groups. Produces no
/// deletions — it returns what *would* be removed for the user to confirm.
@MainActor
struct GenerateCleanupPlanTool {
    static let name = AIToolName.generateCleanupPlan.rawValue

    func makePlan(in context: ModelContext) -> CleanupPlan {
        let ranked = GroupRankingResolver.rankedGroups(in: context)
        let groupRankings = ranked.map { (id: $0.group.id, ranking: $0.ranking) }
        return CleanupPlanGenerator().make(groupRankings: groupRankings)
    }

    func run(in context: ModelContext) -> AIToolResult {
        let plan = makePlan(in: context)
        let removable = plan.suggestedRemovalAssetIds.count
        let protected = plan.protectedAssetIds.count
        guard removable > 0 || protected > 0 else {
            return AIToolResult(speech: "There's nothing to clean up yet. Try running a scan first.")
        }
        return AIToolResult(
            speech: "I recommend reviewing \(removable) \(plural("photo", removable)) for removal. "
                + "I protected \(protected) \(plural("photo", protected)). "
                + "Nothing is deleted until you review and confirm.",
            didAct: false
        )
    }
}

/// Explains, in grounded language, why a photo was recommended. Uses only
/// structured scores/badges — never raw image data — so it can't overstate
/// certainty. Falls back to the MVP 2 template wording.
@MainActor
struct ExplainRecommendationTool {
    static let name = AIToolName.explainRecommendation.rawValue

    func run(in context: ModelContext) -> AIToolResult {
        guard let text = KeeperExplanation.forTopGroup(in: context) else {
            return AIToolResult(speech: "I don't have a recommendation to explain yet. Try running a scan first.")
        }
        return AIToolResult(speech: text)
    }
}

/// Speaks a friendly summary of the last scan's results. Read-only.
@MainActor
struct ShowCleanupSummaryTool {
    static let name = AIToolName.showCleanupSummary.rawValue

    func run(in context: ModelContext) -> AIToolResult {
        AIToolResult(speech: CleanupSummary.text(in: context))
    }
}

/// Creates a Photos album from the recommended keepers. Additive and reversible
/// — it never deletes. Touches PhotoKit, so the success path runs on-device.
@MainActor
struct CreateAlbumTool {
    static let name = AIToolName.createAlbum.rawValue
    let albumService: AlbumCreationService

    init(albumService: AlbumCreationService = AlbumCreationService()) {
        self.albumService = albumService
    }

    func run(named name: String, in context: ModelContext) async -> AIToolResult {
        let keepers = BestShotsCollector.keeperIdentifiers(in: context)
        guard !keepers.isEmpty else {
            return AIToolResult(speech: "I don't have any best shots to save yet. Try running a scan first.")
        }
        let result = await albumService.createAlbum(named: name, assetIdentifiers: keepers)
        switch result {
        case .success(let count):
            return AIToolResult(speech: "I created the album \"\(name)\" with \(count) \(plural("photo", count)).", didAct: true)
        case .empty:
            return AIToolResult(speech: "I couldn't find those photos to add to an album.")
        case .failed(let message):
            return AIToolResult(speech: "I wasn't able to create the album: \(message)")
        }
    }
}
