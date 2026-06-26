import Foundation
import SwiftData

/// The single entry point the AI session layer (Step 2) uses to enumerate and
/// run app tools. It owns the model provider (for the availability gate) and
/// vends each tool. The registry is the boundary that guarantees the model can
/// only do what these tools allow — there is no deletion tool.
@MainActor
struct AIToolRegistry {
    let provider: AIModelProviding
    let router: IntentRouter

    init(provider: AIModelProviding, router: IntentRouter) {
        self.provider = provider
        self.router = router
    }

    /// Convenience using the shared router. The delegating body is main-actor
    /// isolated, so referencing `IntentRouter.shared` here is safe under Swift 6.
    init(provider: AIModelProviding) {
        self.init(provider: provider, router: .shared)
    }

    /// Whether AI features are usable; callers fall back to templates when not.
    var availability: AIAvailability { provider.availability }

    /// The catalog of tool names exposed to the model.
    var toolNames: [String] { AIToolName.allCases.map(\.rawValue) }

    // MARK: - Tool accessors

    var startPhotoScan: StartPhotoScanTool { StartPhotoScanTool(router: router) }
    var getDuplicateGroups: GetDuplicateGroupsTool { GetDuplicateGroupsTool() }
    var getGroupDetails: GetGroupDetailsTool { GetGroupDetailsTool() }
    var updateDedupeMode: UpdateDedupeModeTool { UpdateDedupeModeTool() }
    var generateCleanupPlan: GenerateCleanupPlanTool { GenerateCleanupPlanTool() }
    var explainRecommendation: ExplainRecommendationTool { ExplainRecommendationTool() }
    var showCleanupSummary: ShowCleanupSummaryTool { ShowCleanupSummaryTool() }
    var createAlbum: CreateAlbumTool { CreateAlbumTool() }
}
