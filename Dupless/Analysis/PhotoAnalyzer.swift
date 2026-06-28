import Photos
import UIKit

/// Analyzes a single asset into a Sendable `CachedAnalysis`: thumbnail → hash +
/// feature print + blocking key (MVP 1) plus quality scores, face detection, and
/// protection flags (MVP 2). Runs off the main actor; on-device only.
struct PhotoAnalyzer {
    /// Current analysis-pipeline version, stamped onto every record. Bump when a
    /// change makes older cached records unusable so a scan recomputes them
    /// instead of trusting stale data. v1: face prints moved to a high-res crop
    /// (the 256px-thumbnail prints couldn't distinguish people).
    static let analysisVersion = 1

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
        var quality = qualityService.scores(for: image)
        quality.colorSignature = Self.colorSignature(for: image)
        let (faceCount, personDetected) = faceService.detect(in: image)
        // Face-identity prints need a higher-res crop than the 256px thumbnail
        // (faces there are too small to tell people apart), so fetch a larger
        // on-device render — but only when a face was actually detected.
        var faceprints: [Data] = []
        if personDetected, let faceImage = await loader.faceSource(for: asset) {
            faceprints = faceService.faceprints(in: faceImage)
        }
        let flags = Self.flags(for: asset, faceCount: faceCount,
                               personDetected: personDetected, faceprints: faceprints)

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

    /// Coarse RGB color histogram of the thumbnail, returned as 64 bytes (one per
    /// bin). The image is drawn into a small 32×32 RGBA context and each pixel is
    /// bucketed by the top 2 bits of each channel — a 4×4×4 = 64-bin cube. Bins are
    /// normalized to 0...255 so two photos of differing pixel counts compare
    /// directly. Position-invariant by construction: it captures *what colors* are
    /// present, not where — so a bust-level subject in a red vs. a blue top reads as
    /// different even against an identical backdrop. Returns nil if the image can't
    /// be rasterized (grouping then uses the visual signals only). On-device only.
    nonisolated static func colorSignature(for image: UIImage) -> Data? {
        let side = 32
        let binCount = 64
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let context = CGContext(
            data: &pixels, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side * 4, space: colorSpace, bitmapInfo: bitmapInfo
        ), let cgImage = image.cgImage else { return nil }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))

        var bins = [Int](repeating: 0, count: binCount)
        var pixelCount = 0
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = pixels[i + 3]
            guard alpha > 0 else { continue } // skip transparent padding
            let r = Int(pixels[i]) >> 6      // top 2 bits → 0...3
            let g = Int(pixels[i + 1]) >> 6
            let b = Int(pixels[i + 2]) >> 6
            bins[(r << 4) | (g << 2) | b] += 1
            pixelCount += 1
        }
        guard pixelCount > 0 else { return nil }

        var signature = Data(count: binCount)
        for bin in 0..<binCount {
            // Normalize each bin's share of the image to a 0...255 byte.
            signature[bin] = UInt8(min(255, bins[bin] * 255 / pixelCount))
        }
        return signature
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

    /// Reads PhotoKit metadata into protection flags, carrying the face-detection
    /// result (count + per-face prints) through unchanged.
    nonisolated static func flags(for asset: PHAsset, faceCount: Int,
                                  personDetected: Bool, faceprints: [Data]) -> PhotoFlags {
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
            personDetected: personDetected,
            faceprints: faceprints,
            analysisVersion: analysisVersion
        )
    }
}
