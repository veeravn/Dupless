import Foundation
import SwiftData

/// Persistence layer for scan results and resume.
///
/// Mirrors the data model called out in the MVP 1 spec (`PhotoAssetRecord`,
/// `ImageFeatureRecord`, `DuplicateGroupRecord`, `CleanupSessionRecord`) plus a
/// `ScanCheckpointRecord` so an interrupted scan can resume from cached work.

/// A photo we have seen during a scan, keyed by its stable PhotoKit identifier.
@Model
final class PhotoAssetRecord {
    @Attribute(.unique) var localIdentifier: String
    var creationDate: Date?
    var pixelWidth: Int
    var pixelHeight: Int
    var isFavorite: Bool
    var isScreenshot: Bool
    var lastSeenAt: Date

    init(
        localIdentifier: String,
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        isFavorite: Bool,
        isScreenshot: Bool,
        lastSeenAt: Date = .now
    ) {
        self.localIdentifier = localIdentifier
        self.creationDate = creationDate
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.isFavorite = isFavorite
        self.isScreenshot = isScreenshot
        self.lastSeenAt = lastSeenAt
    }
}

/// Cached analysis for one asset (perceptual hash + Vision feature print +
/// blocking key). Keyed by asset identifier so a resumed scan can skip
/// already-analyzed photos. This is the core of checkpointed scanning.
@Model
final class ImageFeatureRecord {
    @Attribute(.unique) var assetLocalIdentifier: String
    /// `UInt64` perceptual hash stored as `Int` bit pattern.
    var perceptualHashBits: Int
    var featurePrintData: Data?
    var blockingKey: String
    var pixelCount: Int
    /// MVP 2: cached quality metrics + protection flags (Codable value types).
    var quality: QualityScores
    var flags: PhotoFlags
    var computedAt: Date

    init(
        assetLocalIdentifier: String,
        perceptualHashBits: Int,
        featurePrintData: Data?,
        blockingKey: String,
        pixelCount: Int,
        quality: QualityScores = .unknown,
        flags: PhotoFlags = .none,
        computedAt: Date = .now
    ) {
        self.assetLocalIdentifier = assetLocalIdentifier
        self.perceptualHashBits = perceptualHashBits
        self.featurePrintData = featurePrintData
        self.blockingKey = blockingKey
        self.pixelCount = pixelCount
        self.quality = quality
        self.flags = flags
        self.computedAt = computedAt
    }

    convenience init(cached: CachedAnalysis) {
        self.init(
            assetLocalIdentifier: cached.id,
            perceptualHashBits: cached.hashBits,
            featurePrintData: cached.featurePrintData,
            blockingKey: cached.blockingKey,
            pixelCount: cached.pixelCount,
            quality: cached.quality,
            flags: cached.flags
        )
    }

    var cachedAnalysis: CachedAnalysis {
        CachedAnalysis(
            id: assetLocalIdentifier,
            pixelCount: pixelCount,
            blockingKey: blockingKey,
            hash: UInt64(bitPattern: Int64(perceptualHashBits)),
            featurePrintData: featurePrintData,
            quality: quality,
            flags: flags
        )
    }
}

/// A connected component of visually similar photos (a duplicate group).
@Model
final class DuplicateGroupRecord {
    @Attribute(.unique) var id: UUID
    var memberIdentifiers: [String]
    var confidence: Double
    /// Placeholder keeper in MVP 1 (highest-resolution); MVP 2 adds real ranking.
    var recommendedKeeperIdentifier: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        memberIdentifiers: [String],
        confidence: Double,
        recommendedKeeperIdentifier: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.memberIdentifiers = memberIdentifiers
        self.confidence = confidence
        self.recommendedKeeperIdentifier = recommendedKeeperIdentifier
        self.createdAt = createdAt
    }

    var estimatedRemovableCount: Int { max(0, memberIdentifiers.count - 1) }
}

/// A record of one review/cleanup session for auditability.
@Model
final class CleanupSessionRecord {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var completedAt: Date?
    var removedIdentifiers: [String]
    var scopeDescription: String

    init(
        id: UUID = UUID(),
        startedAt: Date = .now,
        completedAt: Date? = nil,
        removedIdentifiers: [String] = [],
        scopeDescription: String
    ) {
        self.id = id
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.removedIdentifiers = removedIdentifiers
        self.scopeDescription = scopeDescription
    }
}

/// Tracks an in-flight scan so it can be resumed after interruption. Keyed by a
/// scope+options signature; holds the full target list and which identifiers
/// have been analyzed so far.
@Model
final class ScanCheckpointRecord {
    @Attribute(.unique) var signature: String
    var scopeDescription: String
    var sensitivityRaw: String
    var targetIdentifiers: [String]
    var isComplete: Bool
    var startedAt: Date
    var updatedAt: Date

    init(
        signature: String,
        scopeDescription: String,
        sensitivityRaw: String,
        targetIdentifiers: [String],
        isComplete: Bool = false,
        startedAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.signature = signature
        self.scopeDescription = scopeDescription
        self.sensitivityRaw = sensitivityRaw
        self.targetIdentifiers = targetIdentifiers
        self.isComplete = isComplete
        self.startedAt = startedAt
        self.updatedAt = updatedAt
    }
}

enum PersistenceSchema {
    static let models: [any PersistentModel.Type] = [
        PhotoAssetRecord.self,
        ImageFeatureRecord.self,
        DuplicateGroupRecord.self,
        CleanupSessionRecord.self,
        ScanCheckpointRecord.self,
    ]
}
