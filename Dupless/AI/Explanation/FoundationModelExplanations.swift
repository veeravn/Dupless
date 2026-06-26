import Foundation
import FoundationModels

/// Explains a keeper with the on-device model, grounded strictly in the supplied
/// badges/confidence. Falls back to the template wording when the model is
/// unavailable or errors. No image data is ever sent.
struct FoundationModelRecommendationExplainer: RecommendationExplaining {
    let service: FoundationModelService
    let fallback: TemplateRecommendationExplainer

    init(service: FoundationModelService = FoundationModelService()) {
        self.service = service
        self.fallback = TemplateRecommendationExplainer()
    }

    func explainKeeper(_ input: KeeperExplanationInput) async -> String {
        guard service.availability.isAvailable else { return await fallback.explainKeeper(input) }
        do {
            let session = service.makeSession(instructions: Self.instructions)
            return try await session.respond(to: Self.prompt(for: input)).content
        } catch {
            return await fallback.explainKeeper(input)
        }
    }

    static func prompt(for input: KeeperExplanationInput) -> String {
        let keeper = input.keeperBadges.map(\.rawValue).joined(separator: ", ")
        let downsides = input.removalBadges.map(\.rawValue).joined(separator: ", ")
        let confidence = Int((input.confidence * 100).rounded())
        return """
            The group is a \(confidence)% visual match. The recommended photo's \
            qualities: [\(keeper.isEmpty ? "none noted" : keeper)]. The other photos' \
            downsides: [\(downsides.isEmpty ? "none noted" : downsides)]. In one short, \
            friendly sentence, explain why the recommended photo is the best to keep, \
            using only these facts.
            """
    }

    private static let instructions = """
        You explain why a photo was chosen as the best of a group of near-duplicates. \
        Base your explanation only on the provided quality facts. Never claim anything \
        not supported by them, and never suggest deleting protected photos.
        """
}

/// Generates a conversational scan summary with the on-device model from the
/// structured counts. Falls back to the template summary otherwise.
struct FoundationModelCleanupSummaryGenerator: CleanupSummaryGenerating {
    let service: FoundationModelService
    let fallback: TemplateCleanupSummaryGenerator

    init(service: FoundationModelService = FoundationModelService()) {
        self.service = service
        self.fallback = TemplateCleanupSummaryGenerator()
    }

    func summarize(_ stats: CleanupStats) async -> String {
        guard !stats.isEmpty, service.availability.isAvailable else {
            return await fallback.summarize(stats)
        }
        do {
            let session = service.makeSession(instructions: Self.instructions)
            return try await session.respond(to: Self.prompt(for: stats)).content
        } catch {
            return await fallback.summarize(stats)
        }
    }

    static func prompt(for stats: CleanupStats) -> String {
        """
        Summarize a photo-cleanup scan in one or two friendly sentences using only \
        these numbers: \(stats.groupCount) similar-photo groups; \
        \(stats.reviewableCount) photos recommended for review; protected \
        \(stats.protectedFavorites) favorites, \(stats.protectedLivePhotos) Live Photos, \
        and \(stats.protectedPeople) photos with people. Do not invent any other numbers.
        """
    }

    private static let instructions = """
        You summarize the results of an on-device duplicate-photo scan for the user. \
        Be warm and concise. Use only the numbers provided and never imply anything \
        was deleted — the user always reviews before any cleanup.
        """
}
