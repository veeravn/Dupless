import Foundation
import SwiftData

/// Replaces persisted scan results, deleting the previous run before inserting the
/// current one. Extracted from `ScanEngine` so the replace semantics are
/// unit-testable with an in-memory store.
@MainActor
enum ScanResultWriter {
    static func replaceGroups(_ results: [ScanGroupResult], in context: ModelContext) throws {
        try context.delete(model: DuplicateGroupRecord.self)
        for result in results {
            context.insert(
                DuplicateGroupRecord(
                    memberIdentifiers: result.memberIdentifiers,
                    confidence: result.confidence,
                    recommendedKeeperIdentifier: result.keeperIdentifier
                )
            )
        }
        try context.save()
    }

    static func replaceClusters(_ records: [SessionClusterRecord], in context: ModelContext) throws {
        try context.delete(model: SessionClusterRecord.self)
        for record in records {
            context.insert(record)
        }
        try context.save()
    }
}
