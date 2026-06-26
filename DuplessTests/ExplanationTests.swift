import XCTest
import SwiftData
@testable import CleanShots

final class ExplanationTests: XCTestCase {

    // MARK: - Template recommendation explainer

    func testTemplateExplainerMatchesRecommendationText() async {
        let input = KeeperExplanationInput(confidence: 0.9,
                                           keeperBadges: [.sharpest, .highestResolution],
                                           removalBadges: [.blurry])
        let text = await TemplateRecommendationExplainer().explainKeeper(input)
        XCTAssertEqual(text, RecommendationText.keeperSummary(badges: [.sharpest, .highestResolution]))
        XCTAssertTrue(text.contains("Recommended because"), text)
    }

    // MARK: - Template cleanup summary

    func testTemplateSummaryUsesSpecPhrasingAndProtections() async {
        let stats = CleanupStats(groupCount: 38, reviewableCount: 91,
                                 protectedFavorites: 12, protectedLivePhotos: 7, protectedPeople: 15)
        let text = await TemplateCleanupSummaryGenerator().summarize(stats)
        XCTAssertTrue(text.contains("38 similar-photo groups"), text)
        XCTAssertTrue(text.contains("reviewing 91 photos"), text)
        XCTAssertTrue(text.contains("12 favorites"), text)
        XCTAssertTrue(text.contains("7 Live Photos"), text)
        XCTAssertTrue(text.contains("15 photos with people"), text)
        XCTAssertTrue(text.contains(", and "), text) // Oxford-style join
    }

    func testTemplateSummaryOmitsZeroProtectionCategories() async {
        let stats = CleanupStats(groupCount: 2, reviewableCount: 3,
                                 protectedFavorites: 1, protectedLivePhotos: 0, protectedPeople: 0)
        let text = await TemplateCleanupSummaryGenerator().summarize(stats)
        XCTAssertTrue(text.contains("I protected 1 favorite."), text)
        XCTAssertFalse(text.contains("Live"), text)
        XCTAssertFalse(text.contains("people"), text)
    }

    func testTemplateSummaryDropsProtectionSentenceWhenNoneProtected() async {
        let stats = CleanupStats(groupCount: 1, reviewableCount: 1,
                                 protectedFavorites: 0, protectedLivePhotos: 0, protectedPeople: 0)
        let text = await TemplateCleanupSummaryGenerator().summarize(stats)
        XCTAssertFalse(text.contains("protected"), text)
    }

    func testTemplateSummaryEmpty() async {
        let text = await TemplateCleanupSummaryGenerator().summarize(.empty)
        XCTAssertTrue(text.contains("No duplicate groups"), text)
    }

    // MARK: - Prompt grounding (no model, just the prompt text)

    func testKeeperPromptIsGroundedInProvidedFacts() {
        let input = KeeperExplanationInput(confidence: 0.94, keeperBadges: [.sharpest], removalBadges: [.blurry])
        let prompt = FoundationModelRecommendationExplainer.prompt(for: input)
        XCTAssertTrue(prompt.contains("94%"), prompt)
        XCTAssertTrue(prompt.contains("Sharpest"), prompt)
        XCTAssertTrue(prompt.contains("only these facts"), prompt)
        XCTAssertFalse(prompt.lowercased().contains("image data"), prompt)
    }

    func testSummaryPromptForbidsInventingNumbers() {
        let stats = CleanupStats(groupCount: 5, reviewableCount: 9, protectedFavorites: 2, protectedLivePhotos: 1, protectedPeople: 3)
        let prompt = FoundationModelCleanupSummaryGenerator.prompt(for: stats)
        XCTAssertTrue(prompt.contains("5 similar-photo groups"), prompt)
        XCTAssertTrue(prompt.contains("Do not invent any other numbers"), prompt)
    }
}
