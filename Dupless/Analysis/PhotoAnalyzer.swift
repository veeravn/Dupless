import Photos
import UIKit

/// Analyzes a single asset into a Sendable `CachedAnalysis`: thumbnail → hash +
/// feature print + blocking key (MVP 1) plus quality scores, face detection, and
/// protection flags (MVP 2). Runs off the main actor; on-device only.
struct PhotoAnalyzer {
    private let hashService = PerceptualHashService()
    private let featureService = VisionFeaturePrintService()
    private let qualityService = QualityScoringService()
    private let faceService = FacePersonDetectionService()

    nonisolated func analyze(identifier: String, loader: PhotoImageLoader) async -> CachedAnalysis? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
        else { return nil }
        guard let image = await loader.thumbnail(for: asset) else { return nil }
        guard let hash = hashService.hash(for: image) else { return nil }

        let featureData = featureService.featurePrint(for: image).flatMap(FeaturePrintArchive.archive)
        let quality = qualityService.scores(for: image)
        let (faceCount, personDetected) = faceService.detect(in: image)
        let flags = Self.flags(for: asset, faceCount: faceCount, personDetected: personDetected)

        return CachedAnalysis(
            id: identifier,
            pixelCount: asset.pixelWidth * asset.pixelHeight,
            blockingKey: BlockingKey.make(for: asset),
            hash: hash,
            featurePrintData: featureData,
            quality: quality,
            flags: flags,
            metadata: Self.metadata(for: asset)
        )
    }

    /// Captures cheap session metadata (time/GPS/burst/aspect) from PhotoKit
    /// properties — no image data is read here.
    nonisolated static func metadata(for asset: PHAsset) -> PhotoMetadata {
        PhotoMetadata(
            creationDate: asset.creationDate,
            latitude: asset.location?.coordinate.latitude,
            longitude: asset.location?.coordinate.longitude,
            burstIdentifier: asset.burstIdentifier,
            aspectRatio: asset.pixelHeight > 0 ? Double(asset.pixelWidth) / Double(asset.pixelHeight) : 0
        )
    }

    /// Reads PhotoKit metadata into protection flags.
    nonisolated static func flags(for asset: PHAsset, faceCount: Int, personDetected: Bool) -> PhotoFlags {
        let resources = PHAssetResource.assetResources(for: asset)
        let isEdited = resources.contains { $0.type == .adjustmentData || $0.type == .fullSizePhoto }
        let isLive = asset.mediaSubtypes.contains(.photoLive)
        let isShared = asset.sourceType.contains(.typeCloudShared)

        return PhotoFlags(
            isFavorite: asset.isFavorite,
            isEdited: isEdited,
            isLivePhoto: isLive,
            isHidden: asset.isHidden,
            isShared: isShared,
            faceCount: faceCount,
            personDetected: personDetected
        )
    }
}
