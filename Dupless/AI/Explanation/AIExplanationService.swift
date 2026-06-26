import Foundation
import SwiftData

/// Step 4-facing facade: combines the structured-input builders with the
/// explainer/summarizer. Defaults to the Foundation Models implementations
/// (which fall back to templates); tests inject the template impls directly.
@MainActor
struct AIExplanationService {
    let explainer: RecommendationExplaining
    let summarizer: CleanupSummaryGenerating

    init(
        explainer: RecommendationExplaining = FoundationModelRecommendationExplainer(),
        summarizer: CleanupSummaryGenerating = FoundationModelCleanupSummaryGenerator()
    ) {
        self.explainer = explainer
        self.summarizer = summarizer
    }

    /// Explains the highest-confidence group's keeper, or nil if there's nothing
    /// to explain yet.
    func explainTopGroup(in context: ModelContext) async -> String? {
        guard let input = KeeperExplanationInputBuilder.forTopGroup(in: context) else { return nil }
        return await explainer.explainKeeper(input)
    }

    /// Explains a specific group's keeper.
    func explain(_ group: DuplicateGroupRecord, in context: ModelContext) async -> String? {
        guard let input = KeeperExplanationInputBuilder.make(for: group, in: context) else { return nil }
        return await explainer.explainKeeper(input)
    }

    /// A conversational summary of the last scan.
    func summary(in context: ModelContext) async -> String {
        await summarizer.summarize(CleanupStatsBuilder.make(in: context))
    }
}
