import Foundation
import SwiftData

/// Single shared SwiftData container used by both the app and its App Intents,
/// so a Siri-triggered intent reads/writes the same on-device store.
///
/// Versioned via `CleanShotsMigrationPlan`, so schema changes migrate the user's
/// store rather than resetting it. The wipe-and-recreate fallback below is a
/// pre-release safety net only — it handles the one-time transition from the old
/// *unversioned* store to V1. Real migrations belong in the plan, where failures
/// should be surfaced, never silently discarded.
enum SharedStore {
    static let container: ModelContainer = {
        let schema = Schema(versionedSchema: SchemaV1.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, migrationPlan: CleanShotsMigrationPlan.self, configurations: [config])
        } catch {
            // Pre-release only: the legacy unversioned store can't be opened as V1.
            if let url = config.url as URL?, FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                if let restored = try? ModelContainer(for: schema, migrationPlan: CleanShotsMigrationPlan.self, configurations: [config]) {
                    return restored
                }
            }
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
