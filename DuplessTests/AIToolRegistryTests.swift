import XCTest
import SwiftData
@testable import Dupless

@MainActor
final class AIToolRegistryTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema(PersistenceSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    private func registry() -> AIToolRegistry {
        AIToolRegistry(provider: UnavailableModelProvider())
    }

    override func setUp() async throws {
        IntentRouter.shared.route = nil
    }

    // MARK: - Registry shape & availability gate

    func testCatalogExposesAllToolsAndNoDeleteTool() {
        let names = registry().toolNames
        XCTAssertEqual(Set(names), Set(AIToolName.allCases.map(\.rawValue)))
        XCTAssertFalse(names.contains { $0.lowercased().contains("delete") },
                       "There must be no deletion tool exposed to the model.")
    }

    func testAvailabilityPassesThroughProvider() {
        XCTAssertFalse(registry().availability.isAvailable)
    }

    // MARK: - StartPhotoScanTool routes (never deletes)

    func testStartScanRoutesToScanWithResolvedRequest() {
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 1000)
        let command = AIScanCommand(target: .dateRange(start: start, end: end), mode: .balanced)
        let result = registry().startPhotoScan.run(command)

        XCTAssertTrue(result.didAct)
        XCTAssertEqual(IntentRouter.shared.route,
                       .scan(ScanRequest(scope: .dateRange(start: start, end: end),
                                         options: ScanOptions(includeScreenshots: true, excludeFavorites: true),
                                         sensitivity: .balanced)))
    }

    func testScanCommandAlwaysRequiresReview() {
        let command = AIScanCommand(target: .recent(limit: 200), mode: .aggressive)
        XCTAssertTrue(command.requireReview)
    }

    // MARK: - Read tools over an in-memory store

    func testGetDuplicateGroupsCountsGroupsAndReviewable() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["a", "b", "c"], confidence: 0.9, recommendedKeeperIdentifier: "a"))
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["d", "e"], confidence: 0.8, recommendedKeeperIdentifier: "d"))

        let snap = registry().getDuplicateGroups.snapshot(in: context)
        XCTAssertEqual(snap.groupCount, 2)
        XCTAssertEqual(snap.reviewableCount, 3) // (3-1) + (2-1)

        let speech = registry().getDuplicateGroups.run(in: context).speech
        XCTAssertTrue(speech.contains("2 groups"), speech)
    }

    func testGetDuplicateGroupsEmptySuggestsScan() throws {
        let context = try inMemoryContext()
        XCTAssertTrue(registry().getDuplicateGroups.run(in: context).speech.contains("scan"))
    }

    func testGetGroupDetailsDescribesKeeperAndRemovals() throws {
        let context = try inMemoryContext()
        let group = DuplicateGroupRecord(memberIdentifiers: ["big", "small"], confidence: 0.95, recommendedKeeperIdentifier: "big")
        context.insert(group)
        let sharp = QualityScores(sharpness: 0.9, exposure: 0.6, contrast: 0.6, motionBlur: 0.1)
        let dull = QualityScores(sharpness: 0.2, exposure: 0.4, contrast: 0.4, motionBlur: 0.6)
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "big", pixelCount: 9000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: sharp, flags: .none)))
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "small", pixelCount: 1000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: dull, flags: .none)))

        let speech = registry().getGroupDetails.run(groupID: group.id, in: context).speech
        XCTAssertTrue(speech.contains("95% match"), speech)
        XCTAssertTrue(speech.contains("1 photo suggested for removal"), speech)
    }

    func testGetGroupDetailsUnknownGroup() throws {
        let context = try inMemoryContext()
        let speech = registry().getGroupDetails.run(groupID: UUID(), in: context).speech
        XCTAssertTrue(speech.contains("couldn't find"), speech)
    }

    // MARK: - UpdateDedupeModeTool persists

    func testUpdateDedupeModePersists() {
        let result = registry().updateDedupeMode.run(mode: .conservative)
        XCTAssertTrue(result.didAct)
        XCTAssertEqual(AppSettings.defaultSensitivity, .conservative)
        registry().updateDedupeMode.run(mode: .balanced)
        XCTAssertEqual(AppSettings.defaultSensitivity, .balanced)
    }

    // MARK: - GenerateCleanupPlanTool (no deletions)

    func testGenerateCleanupPlanProtectsAndSuggestsRemovals() throws {
        let context = try inMemoryContext()
        let group = DuplicateGroupRecord(memberIdentifiers: ["keep", "drop", "fav"], confidence: 0.9, recommendedKeeperIdentifier: "keep")
        context.insert(group)
        let q = QualityScores.unknown
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "keep", pixelCount: 9000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: QualityScores(sharpness: 0.9, exposure: 0.6, contrast: 0.6, motionBlur: 0.1), flags: .none)))
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "drop", pixelCount: 1000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: q, flags: .none)))
        var favFlags = PhotoFlags.none; favFlags.isFavorite = true
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "fav", pixelCount: 1000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: q, flags: favFlags)))

        let plan = registry().generateCleanupPlan.makePlan(in: context)
        XCTAssertTrue(plan.suggestedRemovalAssetIds.contains("drop"))
        XCTAssertTrue(plan.protectedAssetIds.contains("fav"))
        XCTAssertFalse(plan.suggestedRemovalAssetIds.contains("fav"), "Protected favorite must never be a removal.")

        let speech = registry().generateCleanupPlan.run(in: context).speech
        XCTAssertTrue(speech.contains("review"), speech)
    }

    func testGenerateCleanupPlanEmpty() throws {
        let context = try inMemoryContext()
        XCTAssertTrue(registry().generateCleanupPlan.run(in: context).speech.contains("scan"))
    }

    // MARK: - Explain / summary read tools

    func testExplainRecommendationFallsBackToTemplate() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["big", "small"], confidence: 0.95, recommendedKeeperIdentifier: "big"))
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "big", pixelCount: 9000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: QualityScores(sharpness: 0.9, exposure: 0.5, contrast: 0.5, motionBlur: 0.1), flags: .none)))
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "small", pixelCount: 1000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: QualityScores.unknown, flags: .none)))

        let speech = registry().explainRecommendation.run(in: context).speech
        XCTAssertTrue(speech.contains("Recommended because"), speech)
    }

    func testShowCleanupSummaryDelegates() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["a", "b"], confidence: 0.9, recommendedKeeperIdentifier: "a"))
        let speech = registry().showCleanupSummary.run(in: context).speech
        XCTAssertEqual(speech, CleanupSummary.text(in: context))
    }

    // MARK: - CreateAlbumTool guard (no keepers)

    func testCreateAlbumWithNoKeepersIsGuarded() async throws {
        let context = try inMemoryContext()
        let speech = await registry().createAlbum.run(named: "Best Shots", in: context).speech
        XCTAssertTrue(speech.contains("Try running a scan"), speech)
    }
}
