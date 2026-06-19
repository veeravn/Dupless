import Foundation
import Vision

/// The five scan stages surfaced in ScanProgressView.
enum ScanStage: String, Sendable, CaseIterable {
    case indexing = "Indexing photos"
    case analyzing = "Analyzing thumbnails"
    case finding = "Finding similar photos"
    case grouping = "Building groups"
    case preparing = "Preparing review"
}

/// Sendable result of grouping, safe to hand across actor boundaries and to
/// persist. Holds only value types — no Vision objects.
struct ScanGroupResult: Sendable, Equatable {
    let memberIdentifiers: [String]
    let confidence: Double
    let keeperIdentifier: String?
}

/// Per-asset analysis used by the grouper. `feature` is optional so grouping can
/// be exercised in tests with hash-only items (Hamming fallback distance).
struct AnalyzedPhoto {
    let id: String
    let pixelCount: Int
    let blockingKey: String
    let hash: UInt64
    let feature: VNFeaturePrintObservation?

    init(id: String, pixelCount: Int, blockingKey: String, hash: UInt64, feature: VNFeaturePrintObservation? = nil) {
        self.id = id
        self.pixelCount = pixelCount
        self.blockingKey = blockingKey
        self.hash = hash
        self.feature = feature
    }
}

/// Sendable snapshot of one asset's analysis, used to cross actor boundaries and
/// to persist for resume. The feature print is archived to `Data`.
struct CachedAnalysis: Sendable, Equatable {
    let id: String
    let pixelCount: Int
    let blockingKey: String
    /// `UInt64` perceptual hash stored as `Int` bit pattern (SwiftData-friendly).
    let hashBits: Int
    let featurePrintData: Data?
    /// MVP 2 quality metrics + protection flags, cached alongside the hash.
    let quality: QualityScores
    let flags: PhotoFlags
    /// MVP 5 session metadata (time/GPS/burst), cached for drone/burst clustering.
    let metadata: PhotoMetadata

    var hash: UInt64 { UInt64(bitPattern: Int64(hashBits)) }

    init(
        id: String,
        pixelCount: Int,
        blockingKey: String,
        hash: UInt64,
        featurePrintData: Data?,
        quality: QualityScores = .unknown,
        flags: PhotoFlags = .none,
        metadata: PhotoMetadata = .unknown
    ) {
        self.id = id
        self.pixelCount = pixelCount
        self.blockingKey = blockingKey
        self.hashBits = Int(bitPattern: UInt(hash))
        self.featurePrintData = featurePrintData
        self.quality = quality
        self.flags = flags
        self.metadata = metadata
    }

    /// Reconstructs an `AnalyzedPhoto`, unarchiving the feature print if present.
    func toAnalyzedPhoto() -> AnalyzedPhoto {
        AnalyzedPhoto(
            id: id,
            pixelCount: pixelCount,
            blockingKey: blockingKey,
            hash: hash,
            feature: featurePrintData.flatMap(FeaturePrintArchive.unarchive)
        )
    }

    /// A photo ready for best-shot ranking.
    var rankablePhoto: RankablePhoto {
        RankablePhoto(id: id, pixelCount: pixelCount, quality: quality, flags: flags)
    }
}
