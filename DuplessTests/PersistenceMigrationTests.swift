import XCTest
import SwiftData
@testable import Dupless

@MainActor
final class PersistenceMigrationTests: XCTestCase {

    // MARK: - Schema / plan shape

    func testSchemaV1VersionAndModels() {
        XCTAssertEqual(SchemaV1.versionIdentifier, Schema.Version(1, 0, 0))
        // All persisted models are registered in the versioned schema.
        XCTAssertEqual(SchemaV1.models.count, 6)
        let names = SchemaV1.models.map { String(describing: $0) }
        for expected in ["PhotoAssetRecord", "ImageFeatureRecord", "DuplicateGroupRecord",
                         "CleanupSessionRecord", "ScanCheckpointRecord", "SessionClusterRecord"] {
            XCTAssertTrue(names.contains(expected), "Missing \(expected) from SchemaV1")
        }
    }

    func testPersistenceSchemaTracksVersionedSchema() {
        XCTAssertEqual(PersistenceSchema.models.count, SchemaV1.models.count)
    }

    func testMigrationPlanDeclaresV1() {
        XCTAssertEqual(DuplessMigrationPlan.schemas.count, 1)
        XCTAssertTrue(DuplessMigrationPlan.schemas.first == SchemaV1.self)
        // No stages yet — V1 is the baseline.
        XCTAssertTrue(DuplessMigrationPlan.stages.isEmpty)
    }

    // MARK: - The actual guarantee: reopening the store keeps data

    func testVersionedStorePersistsDataAcrossReopen() throws {
        let url = URL.temporaryDirectory.appending(path: "cleanshots-migration-\(UUID().uuidString).store")
        defer {
            for ext in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: url.path + ext))
            }
        }
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, url: url)

        // Write through a versioned container.
        do {
            let container = try ModelContainer(for: schema, migrationPlan: DuplessMigrationPlan.self, configurations: [config])
            let context = ModelContext(container)
            context.insert(DuplicateGroupRecord(memberIdentifiers: ["a", "b"], confidence: 0.91, recommendedKeeperIdentifier: "a"))
            context.insert(SessionClusterRecord(assetIdentifiers: ["x", "y"], sessionType: .burst, startDate: .now, endDate: .now, recommendedBestShotIds: ["x"]))
            try context.save()
        }

        // Reopen the same on-disk store — data must survive (not be wiped).
        let reopened = try ModelContainer(for: schema, migrationPlan: DuplessMigrationPlan.self, configurations: [config])
        let context = ModelContext(reopened)
        let groups = try context.fetch(FetchDescriptor<DuplicateGroupRecord>())
        let sessions = try context.fetch(FetchDescriptor<SessionClusterRecord>())

        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.recommendedKeeperIdentifier, "a")
        XCTAssertEqual(sessions.count, 1)
        XCTAssertEqual(sessions.first?.sessionType, .burst)
    }
}
