import XCTest
import SwiftData
@testable import CleanShots

@MainActor
final class ScanResultWriterTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema(PersistenceSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    func testReplaceGroupsClearsPreviousRun() throws {
        let context = try inMemoryContext()
        // A previous scan's results.
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["old1", "old2"], confidence: 0.7, recommendedKeeperIdentifier: "old1"))
        try context.save()

        try ScanResultWriter.replaceGroups([
            ScanGroupResult(memberIdentifiers: ["a", "b"], confidence: 0.9, keeperIdentifier: "a"),
            ScanGroupResult(memberIdentifiers: ["c", "d"], confidence: 0.8, keeperIdentifier: "c"),
        ], in: context)

        let groups = try context.fetch(FetchDescriptor<DuplicateGroupRecord>())
        XCTAssertEqual(groups.count, 2, "Old groups must be gone, replaced by the new run.")
        XCTAssertFalse(groups.contains { $0.recommendedKeeperIdentifier == "old1" })
        XCTAssertEqual(Set(groups.compactMap(\.recommendedKeeperIdentifier)), ["a", "c"])
    }

    func testReplaceGroupsWithEmptyClearsAll() throws {
        let context = try inMemoryContext()
        context.insert(DuplicateGroupRecord(memberIdentifiers: ["x", "y"], confidence: 0.9, recommendedKeeperIdentifier: "x"))
        try context.save()

        try ScanResultWriter.replaceGroups([], in: context)
        XCTAssertTrue(try context.fetch(FetchDescriptor<DuplicateGroupRecord>()).isEmpty)
    }

    func testReplaceClustersClearsPreviousRun() throws {
        let context = try inMemoryContext()
        context.insert(SessionClusterRecord(assetIdentifiers: ["old"], sessionType: .event, startDate: .now, endDate: .now))
        try context.save()

        try ScanResultWriter.replaceClusters([
            SessionClusterRecord(assetIdentifiers: ["a", "b"], sessionType: .burst, startDate: .now, endDate: .now, recommendedBestShotIds: ["a"]),
        ], in: context)

        let clusters = try context.fetch(FetchDescriptor<SessionClusterRecord>())
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters.first?.sessionType, .burst)
    }
}
