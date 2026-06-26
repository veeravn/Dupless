import SwiftData

/// Version 1 of the on-disk schema — the baseline. Establishing a *versioned*
/// schema now means future `@Model` changes can migrate the user's store instead
/// of wiping it (which is what happened pre-release).
///
/// To evolve the schema:
///   1. Add `SchemaV2: VersionedSchema` with `versionIdentifier = Schema.Version(2, 0, 0)`
///      and the updated model set (versioned copies of any changed `@Model`).
///   2. Append it to `CleanShotsMigrationPlan.schemas`.
///   3. Add a `MigrationStage` from V1 → V2:
///        - `.lightweight` for additive / defaultable changes (new optional field,
///          new model, renamed-with-default).
///        - `.custom(...)` when data must be transformed.
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            PhotoAssetRecord.self,
            ImageFeatureRecord.self,
            DuplicateGroupRecord.self,
            CleanupSessionRecord.self,
            ScanCheckpointRecord.self,
            SessionClusterRecord.self,
        ]
    }
}

/// Declares how the on-disk store migrates between schema versions. Only V1 exists
/// today, so there are no stages yet — but the plan is wired into the container so
/// the next schema change is a real migration, not a reset.
enum CleanShotsMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [SchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
