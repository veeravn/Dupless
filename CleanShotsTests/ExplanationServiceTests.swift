import XCTest
import SwiftData
@testable import CleanShots

@MainActor
final class ExplanationServiceTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema(PersistenceSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func record(_ id: String, pixels: Int, quality: QualityScores = .unknown, flags: PhotoFlags = .none) -> ImageFeatureRecord {
        ImageFeatureRecord(cached: CachedAnalysis(id: id, pixelCount: pixels, blockingKey: "k", hash: 1, featurePrintData: nil, quality: quality, flags: flags))
    }

    /// A group with a clear sharp/high-res keeper, a blurry low-res removal, and a
    /// protected favorite + a Live Photo with a person.
    private func seed(_ context: ModelContext) {
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["keep", "drop", "fav", "live"], confidence: 0.9, recommendedKeeperIdentifier: "keep"))
        context.insert(record("keep", pixels: 9000, quality: QualityScores(sharpness: 0.95, exposure: 0.6, contrast: 0.6, motionBlur: 0.05)))
        context.insert(record("drop", pixels: 1000, quality: QualityScores(sharpness: 0.1, exposure: 0.3, contrast: 0.3, motionBlur: 0.8)))
        var favFlags = PhotoFlags.none; favFlags.isFavorite = true
        context.insert(record("fav", pixels: 1000, flags: favFlags))
        var liveFlags = PhotoFlags.none; liveFlags.isLivePhoto = true; liveFlags.personDetected = true; liveFlags.faceCount = 1
        context.insert(record("live", pixels: 1000, flags: liveFlags))
    }

    // MARK: - CleanupStatsBuilder

    func testStatsBuilderCountsGroupsReviewableAndProtections() throws {
        let context = try inMemoryContext()
        seed(context)
        let stats = CleanupStatsBuilder.make(in: context)

        XCTAssertEqual(stats.groupCount, 1)
        XCTAssertEqual(stats.protectedFavorites, 1)
        XCTAssertEqual(stats.protectedLivePhotos, 1)
        XCTAssertEqual(stats.protectedPeople, 1)
        // "keep" is the keeper; "fav" and "live" are protected; only "drop" is removable.
        XCTAssertEqual(stats.reviewableCount, 1)
    }

    func testStatsBuilderEmptyWhenNoGroups() throws {
        let context = try inMemoryContext()
        XCTAssertTrue(CleanupStatsBuilder.make(in: context).isEmpty)
    }

    // MARK: - KeeperExplanationInputBuilder

    func testKeeperInputBuilderCapturesKeeperBadgesAndRemovalDownsides() throws {
        let context = try inMemoryContext()
        seed(context)
        let input = try XCTUnwrap(KeeperExplanationInputBuilder.forTopGroup(in: context))

        XCTAssertEqual(input.confidence, 0.9, accuracy: 0.0001)
        XCTAssertTrue(input.keeperBadges.contains(.sharpest), "\(input.keeperBadges)")
        XCTAssertTrue(input.keeperBadges.contains(.highestResolution), "\(input.keeperBadges)")
        // Removal downsides should surface negatives like blurry / lower resolution.
        XCTAssertTrue(input.removalBadges.allSatisfy(\.isNegative), "\(input.removalBadges)")
        XCTAssertTrue(input.removalBadges.contains(.blurry) || input.removalBadges.contains(.lowerResolution), "\(input.removalBadges)")
    }

    func testKeeperInputBuilderNilWhenEmpty() throws {
        let context = try inMemoryContext()
        XCTAssertNil(KeeperExplanationInputBuilder.forTopGroup(in: context))
    }

    // MARK: - AIExplanationService facade (template impls)

    private func service() -> AIExplanationService {
        AIExplanationService(explainer: TemplateRecommendationExplainer(),
                             summarizer: TemplateCleanupSummaryGenerator())
    }

    func testFacadeExplainsTopGroup() async throws {
        let context = try inMemoryContext()
        seed(context)
        let text = await service().explainTopGroup(in: context)
        XCTAssertNotNil(text)
        XCTAssertTrue(text!.contains("Recommended because"), text ?? "nil")
    }

    func testFacadeExplainTopGroupNilWhenEmpty() async throws {
        let context = try inMemoryContext()
        let text = await service().explainTopGroup(in: context)
        XCTAssertNil(text)
    }

    func testFacadeSummaryMatchesTemplate() async throws {
        let context = try inMemoryContext()
        seed(context)
        let text = await service().summary(in: context)
        let expected = await TemplateCleanupSummaryGenerator().summarize(CleanupStatsBuilder.make(in: context))
        XCTAssertEqual(text, expected)
        XCTAssertTrue(text.contains("1 similar-photo group"), text)
    }
}
