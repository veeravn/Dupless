import Foundation
import SwiftData

/// Single shared SwiftData container used by both the app and its App Intents,
/// so a Siri-triggered intent reads/writes the same on-device store.
///
/// Pre-release resilience: if the on-disk store can't migrate to the current
/// schema, wipe and recreate rather than crashing. A shipping build would use a
/// `SchemaMigrationPlan` instead.
enum SharedStore {
    static let container: ModelContainer = {
        let schema = Schema(PersistenceSchema.models)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            if let url = config.url as URL?, FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
                if let restored = try? ModelContainer(for: schema, configurations: [config]) {
                    return restored
                }
            }
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()
}
