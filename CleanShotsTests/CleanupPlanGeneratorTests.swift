import XCTest
@testable import CleanShots

final class CleanupPlanGeneratorTests: XCTestCase {
    private let generator = CleanupPlanGenerator()

    private func ranking(keeper: String?, removals: [String], protected: [String] = []) -> GroupRanking {
        GroupRanking(keeperIdentifier: keeper, suggestedRemovalIdentifiers: removals,
                     protectedIdentifiers: protected, finalScores: [:], badges: [:])
    }

    func testAggregatesRemovalsAndProtections() {
        let plan = generator.make(groupRankings: [
            (UUID(), ranking(keeper: "a", removals: ["b", "c"])),
            (UUID(), ranking(keeper: "d", removals: ["e"], protected: ["f"])),
        ])
        XCTAssertEqual(plan.suggestedRemovalAssetIds, ["b", "c", "e"])
        XCTAssertEqual(Set(plan.protectedAssetIds), ["f"])
        XCTAssertEqual(plan.groups.count, 2)
        XCTAssertTrue(plan.hasRemovals)
    }

    func testAllProtectedGroupProducesWarning() {
        let id = UUID()
        let plan = generator.make(groupRankings: [
            (id, ranking(keeper: "a", removals: [], protected: ["b", "c"])),
        ])
        XCTAssertEqual(plan.warnings, [.allProtected(groupID: id)])
        XCTAssertFalse(plan.hasRemovals)
    }

    func testNoKeeperProducesWarning() {
        let id = UUID()
        let plan = generator.make(groupRankings: [(id, ranking(keeper: nil, removals: []))])
        XCTAssertEqual(plan.warnings, [.noKeeper(groupID: id)])
    }

    func testStorageSavingsSumsRemovalBytes() {
        let plan = generator.make(
            groupRankings: [(UUID(), ranking(keeper: "a", removals: ["b", "c"]))],
            bytesForAsset: { id in id == "b" ? 1000 : 2000 }
        )
        XCTAssertEqual(plan.estimatedStorageSavings, 3000)
    }

    func testStorageSavingsNilWhenNoProvider() {
        let plan = generator.make(groupRankings: [(UUID(), ranking(keeper: "a", removals: ["b"]))])
        XCTAssertNil(plan.estimatedStorageSavings)
    }
}

final class RecommendationTextTests: XCTestCase {
    func testKeeperSummaryListsReasons() {
        let text = RecommendationText.keeperSummary(badges: [.sharpest, .highestResolution])
        XCTAssertEqual(text, "Recommended because it is the sharpest image and has the highest resolution.")
    }

    func testKeeperSummaryFallback() {
        XCTAssertEqual(RecommendationText.keeperSummary(badges: [.lowerResolution]),
                       "Recommended as the best of this group.")
    }

    func testProtectionSummary() {
        XCTAssertEqual(RecommendationText.protectionSummary(reasons: [.favorite]),
                       "Protected because it is a favorite.")
        XCTAssertNil(RecommendationText.protectionSummary(reasons: []))
    }

    func testRemovalSummaryMentionsBlur() {
        XCTAssertEqual(RecommendationText.removalSummary(badges: [.blurry]),
                       "Suggested removal because it is visually similar and has more motion blur.")
    }

    func testRemovalSummaryMentionsResolution() {
        XCTAssertEqual(RecommendationText.removalSummary(badges: [.lowerResolution]),
                       "Suggested removal because it is visually similar and is lower resolution.")
    }
}
