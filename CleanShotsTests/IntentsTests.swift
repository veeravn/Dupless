import XCTest
import SwiftData
@testable import CleanShots

@MainActor
final class IntentsTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema(PersistenceSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    override func setUp() async throws {
        IntentRouter.shared.route = nil
    }

    // MARK: - DedupeMode

    func testDedupeModeMapsToSensitivity() {
        XCTAssertEqual(DedupeModeAppEnum.conservative.sensitivity, .conservative)
        XCTAssertEqual(DedupeModeAppEnum.balanced.sensitivity, .balanced)
        XCTAssertEqual(DedupeModeAppEnum.aggressive.sensitivity, .aggressive)
        // Drone/burst maps to aggressive grouping for MVP 3.
        XCTAssertEqual(DedupeModeAppEnum.droneBurst.sensitivity, .aggressive)
    }

    func testDedupeModeRoundTripFromSensitivity() {
        XCTAssertEqual(DedupeModeAppEnum(sensitivity: .conservative), .conservative)
        XCTAssertEqual(DedupeModeAppEnum(sensitivity: .balanced), .balanced)
        XCTAssertEqual(DedupeModeAppEnum(sensitivity: .aggressive), .aggressive)
    }

    // MARK: - Routing intents

    func testFindDuplicatesRequestsConservativeRecentScan() async throws {
        _ = try await FindDuplicatePhotosIntent().perform()
        XCTAssertEqual(IntentRouter.shared.route,
                       .scan(ScanRequest(scope: .recent(limit: 300), options: .default, sensitivity: .conservative)))
    }

    func testReviewIntentRequestsReviewRoute() async throws {
        _ = try await ReviewDuplicateGroupsIntent().perform()
        XCTAssertEqual(IntentRouter.shared.route, .review)
    }

    func testContinueLastScanRequestsResumeRoute() async throws {
        _ = try await ContinueLastScanIntent().perform()
        XCTAssertEqual(IntentRouter.shared.route, .resume)
    }

    func testFindSimilarWithAlbumRequestsAlbumScope() async throws {
        let intent = FindSimilarPhotosIntent()
        intent.album = PhotoAlbumEntity(id: "ALBUM-1", title: "Trip", photoCount: 10)
        intent.mode = .aggressive
        _ = try await intent.perform()
        XCTAssertEqual(IntentRouter.shared.route,
                       .scan(ScanRequest(scope: .album(localIdentifier: "ALBUM-1"),
                                         options: ScanOptions(includeScreenshots: true, excludeFavorites: true),
                                         sensitivity: .aggressive)))
    }

    func testFindSimilarWithDatesRequestsDateRange() async throws {
        let intent = FindSimilarPhotosIntent()
        let start = Date(timeIntervalSince1970: 0)
        let end = Date(timeIntervalSince1970: 1000)
        intent.startDate = start
        intent.endDate = end
        _ = try await intent.perform()
        XCTAssertEqual(IntentRouter.shared.route,
                       .scan(ScanRequest(scope: .dateRange(start: start, end: end),
                                         options: ScanOptions(includeScreenshots: true, excludeFavorites: true),
                                         sensitivity: AppSettings.defaultSensitivity)))
    }

    // MARK: - Change cleanup mode (non-confirming path)

    func testChangeModeToBalancedPersists() async throws {
        let intent = ChangeCleanupModeIntent()
        intent.mode = .conservative
        _ = try await intent.perform()
        XCTAssertEqual(AppSettings.defaultSensitivity, .conservative)

        intent.mode = .balanced
        _ = try await intent.perform()
        XCTAssertEqual(AppSettings.defaultSensitivity, .balanced)
    }

    // MARK: - Summary / collectors

    func testSummaryWithNoGroups() throws {
        let context = try inMemoryContext()
        XCTAssertTrue(CleanupSummary.text(in: context).contains("No duplicate groups"))
    }

    func testSummaryCountsGroupsAndRemovable() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["a", "b", "c"], confidence: 0.9, recommendedKeeperIdentifier: "a"))
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["d", "e"], confidence: 0.8, recommendedKeeperIdentifier: "d"))
        let text = CleanupSummary.text(in: context)
        XCTAssertTrue(text.contains("2 groups"))
        XCTAssertTrue(text.contains("3 photos")) // (3-1) + (2-1) removable
    }

    func testBestShotsCollectorReturnsKeepers() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["a", "b"], confidence: 0.9, recommendedKeeperIdentifier: "a"))
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["c", "d"], confidence: 0.8, recommendedKeeperIdentifier: "c"))
        XCTAssertEqual(Set(BestShotsCollector.keeperIdentifiers(in: context)), ["a", "c"])
    }

    func testKeeperExplanationForTopGroup() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["big", "small"], confidence: 0.95, recommendedKeeperIdentifier: "big"))
        let sharp = QualityScores(sharpness: 0.9, exposure: 0.5, contrast: 0.5, motionBlur: 0.1)
        let dull = QualityScores(sharpness: 0.2, exposure: 0.5, contrast: 0.5, motionBlur: 0.5)
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "big", pixelCount: 9000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: sharp, flags: .none)))
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(id: "small", pixelCount: 1000, blockingKey: "k", hash: 1, featurePrintData: nil, quality: dull, flags: .none)))

        let explanation = KeeperExplanation.forTopGroup(in: context)
        XCTAssertNotNil(explanation)
        XCTAssertTrue(explanation?.contains("highest resolution") ?? false, explanation ?? "nil")
    }

    func testKeeperExplanationNilWhenEmpty() throws {
        let context = try inMemoryContext()
        XCTAssertNil(KeeperExplanation.forTopGroup(in: context))
    }

    // MARK: - Album creation guard

    func testAlbumCreationWithNoIdentifiersIsEmpty() async {
        let result = await AlbumCreationService().createAlbum(named: "Best Shots", assetIdentifiers: [])
        XCTAssertEqual(result, .empty)
    }
}
