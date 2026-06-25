import Foundation

/// Outcome of running an AI tool. `speech` is a short, user/Siri-facing sentence
/// describing what happened or what was found.
struct AIToolResult: Equatable, Sendable {
    let speech: String
    /// True when the tool changed app state (started a scan, changed a setting,
    /// created an album); false for read-only queries.
    var didAct: Bool = false
}

/// Stable names of the tools the language model may request. These are the ONLY
/// capabilities exposed to the model — it can request these, never reach into
/// PhotoKit or delete photos. There is deliberately no deletion tool: cleanup
/// always routes back to manual review (the MVP 3 safety guarantee).
enum AIToolName: String, CaseIterable, Sendable {
    case startPhotoScan = "StartPhotoScanTool"
    case getDuplicateGroups = "GetDuplicateGroupsTool"
    case getGroupDetails = "GetGroupDetailsTool"
    case updateDedupeMode = "UpdateDedupeModeTool"
    case generateCleanupPlan = "GenerateCleanupPlanTool"
    case createAlbum = "CreateAlbumTool"
    case explainRecommendation = "ExplainRecommendationTool"
    case showCleanupSummary = "ShowCleanupSummaryTool"
}

/// A structured scan request the model (or, in Step 2, the natural-language
/// parser) can produce. Converts to the app's existing `ScanRequest`.
struct AIScanCommand: Equatable, Sendable {
    enum Target: Equatable, Sendable {
        case recent(limit: Int)
        case album(localIdentifier: String)
        case dateRange(start: Date, end: Date)
    }

    /// Default ceiling for an undated scan — keeps a no-date request fast and cool.
    static let defaultRecentLimit = 300
    /// Wider ceiling when a place is named but no date is: location is a post-fetch
    /// filter, so the candidate window has to reach further back to catch an older
    /// trip the user didn't date. Still bounded so the scan stays bounded.
    static let placeScopedRecentLimit = 1000

    var target: Target
    var mode: DedupeModeAppEnum
    var includeScreenshots: Bool = true
    /// Optional subject/theme to narrow the scan to (e.g. "birthday"). Nil scans
    /// the whole scope.
    var contentQuery: String?
    /// Optional place/landmark to narrow the scan to (e.g. "mall of america"),
    /// matched by photo location. Requires the opt-in location lookup.
    var locationQuery: String?
    /// Always true — the model cannot bypass manual review.
    let requireReview: Bool = true

    func toScanRequest() -> ScanRequest {
        let scope: ScanScope
        switch target {
        case .recent(let limit): scope = .recent(limit: limit)
        case .album(let id): scope = .album(localIdentifier: id)
        case .dateRange(let start, let end): scope = .dateRange(start: start, end: end)
        }
        return ScanRequest(
            scope: scope,
            options: ScanOptions(
                includeScreenshots: includeScreenshots, excludeFavorites: true,
                contentQuery: contentQuery, locationQuery: locationQuery
            ),
            sensitivity: mode.sensitivity
        )
    }
}

extension DedupeModeAppEnum {
    /// Lowercased spoken form for narration, e.g. "conservative", "drone or burst".
    var speechName: String {
        switch self {
        case .conservative: return "conservative"
        case .balanced: return "balanced"
        case .aggressive: return "aggressive"
        case .droneBurst: return "drone or burst"
        }
    }
}
