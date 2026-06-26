import XCTest
import SwiftData
@testable import CleanShots

@MainActor
final class SessionClusterRecordTests: XCTestCase {
    private func inMemoryContext() throws -> ModelContext {
        let schema = Schema(PersistenceSchema.models)
        let container = try ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
        )
        return ModelContext(container)
    }

    func testSessionTypeMapsFromRawString() {
        let rec = SessionClusterRecord(assetIdentifiers: ["a"], sessionType: .droneLike,
                                       startDate: .now, endDate: .now)
        XCTAssertEqual(rec.sessionType, .droneLike)
    }

    func testSuggestedRemovalsExcludeBestShotsAndProtected() {
        let rec = SessionClusterRecord(
            assetIdentifiers: ["a", "b", "c", "d"],
            sessionType: .burst,
            startDate: .now, endDate: .now,
            recommendedBestShotIds: ["a"],
            protectedUniqueShotIds: ["b"]
        )
        // a = best, b = protected unique angle, so only c and d are removable.
        XCTAssertEqual(Set(rec.suggestedRemovalIds), ["c", "d"])
    }

    func testPersistsAndFetches() throws {
        let context = try inMemoryContext()
        let start = Date(timeIntervalSince1970: 1000)
        let end = Date(timeIntervalSince1970: 1200)
        context.insert(SessionClusterRecord(
            assetIdentifiers: ["a", "b", "c"],
            sessionType: .droneLike,
            startDate: start, endDate: end,
            locationBucket: "37.50,-122.20",
            recommendedBestShotIds: ["a"],
            protectedUniqueShotIds: ["b"]
        ))
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<SessionClusterRecord>()).first)
        XCTAssertEqual(fetched.sessionType, .droneLike)
        XCTAssertEqual(fetched.assetIdentifiers, ["a", "b", "c"])
        XCTAssertEqual(fetched.locationBucket, "37.50,-122.20")
        XCTAssertEqual(fetched.startDate, start)
        XCTAssertEqual(Set(fetched.suggestedRemovalIds), ["c"])
    }

    /// The new model must coexist with the existing ones in the shared schema, and
    /// ImageFeatureRecord must persist its new metadata field.
    func testSchemaPersistsFeatureMetadata() throws {
        let context = try inMemoryContext()
        let meta = PhotoMetadata(creationDate: Date(timeIntervalSince1970: 500),
                                 latitude: 1.5, longitude: -2.5, burstIdentifier: "B", aspectRatio: 1.0)
        context.insert(ImageFeatureRecord(cached: CachedAnalysis(
            id: "asset-1", pixelCount: 100, blockingKey: "k", hash: 3, featurePrintData: nil, metadata: meta
        )))
        try context.save()

        let fetched = try XCTUnwrap(try context.fetch(FetchDescriptor<ImageFeatureRecord>()).first)
        XCTAssertEqual(fetched.metadata, meta)
    }
}
