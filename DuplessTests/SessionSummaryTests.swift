import XCTest
import SwiftData
@testable import Dupless

@MainActor
final class SessionSummaryTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema(PersistenceSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    func testSummaryUsesSpecPhrasing() {
        let stats = SessionStats(clusterCount: 11, bestShotCount: 18, protectedUniqueCount: 7, redundantCount: 43)
        let text = SessionSummaryGenerator().summarize(stats)
        XCTAssertTrue(text.contains("11 sequence groups"), text)
        XCTAssertTrue(text.contains("18 best shots"), text)
        XCTAssertTrue(text.contains("7 unique angles"), text)
        XCTAssertTrue(text.contains("43 redundant photos"), text)
    }

    func testSummaryPluralization() {
        let stats = SessionStats(clusterCount: 1, bestShotCount: 1, protectedUniqueCount: 1, redundantCount: 1)
        let text = SessionSummaryGenerator().summarize(stats)
        XCTAssertTrue(text.contains("1 sequence group."), text)
        XCTAssertTrue(text.contains("1 best shot."), text)
        XCTAssertTrue(text.contains("1 unique angle."), text)
        XCTAssertTrue(text.contains("1 redundant photo."), text)
    }

    func testEmptySummary() {
        XCTAssertTrue(SessionSummaryGenerator().summarize(.empty).contains("No photo sessions"))
    }

    func testStatsBuilderTalliesClusters() throws {
        let context = try inMemoryContext()
        context.insert(SessionClusterRecord(
            assetIdentifiers: ["a", "b", "c", "d"], sessionType: .droneLike, startDate: .now, endDate: .now,
            recommendedBestShotIds: ["a"], protectedUniqueShotIds: ["b"]
        )) // 2 redundant (c, d)
        context.insert(SessionClusterRecord(
            assetIdentifiers: ["e", "f"], sessionType: .burst, startDate: .now, endDate: .now,
            recommendedBestShotIds: ["e"]
        )) // 1 redundant (f)
        try context.save()

        let stats = SessionStatsBuilder.make(in: context)
        XCTAssertEqual(stats.clusterCount, 2)
        XCTAssertEqual(stats.bestShotCount, 2)
        XCTAssertEqual(stats.protectedUniqueCount, 1)
        XCTAssertEqual(stats.redundantCount, 3)
    }

    func testStatsBuilderEmpty() throws {
        let context = try inMemoryContext()
        XCTAssertTrue(SessionStatsBuilder.make(in: context).isEmpty)
    }
}
