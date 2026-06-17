import Photos
import UIKit

/// Loads thumbnails for assets. The MVP 1 spec mandates thumbnail-first
/// analysis for memory safety and to work when iCloud originals aren't
/// downloaded, so this loader never requests full-resolution originals.
///
/// Implemented as a thread-safe class (NSCache + PHCachingImageManager are both
/// safe to use concurrently) so it can be shared with the background scan
/// pipeline without actor hops.
final class PhotoImageLoader: @unchecked Sendable {
    private let imageManager = PHCachingImageManager()
    private let cache = NSCache<NSString, UIImage>()

    /// Shared instance for UI thumbnail display (grid, review).
    static let shared = PhotoImageLoader()

    /// Default thumbnail edge used for grid display and analysis.
    static let thumbnailSize = CGSize(width: 256, height: 256)

    init() {
        cache.countLimit = 400
    }

    /// Requests a thumbnail for an asset. Returns nil if PhotoKit cannot produce
    /// an image (e.g. asset unavailable).
    func thumbnail(
        for asset: PHAsset,
        targetSize: CGSize = PhotoImageLoader.thumbnailSize
    ) async -> UIImage? {
        let key = cacheKey(asset.localIdentifier, targetSize)
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false // on-device only for analysis
        options.isSynchronous = false

        let image: UIImage? = await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                guard !didResume else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                // Wait for the non-degraded image; resume on failure too.
                if let image, !isDegraded {
                    didResume = true
                    continuation.resume(returning: image)
                } else if image == nil {
                    didResume = true
                    continuation.resume(returning: nil)
                }
            }
        }

        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    private func cacheKey(_ id: String, _ size: CGSize) -> NSString {
        "\(id)-\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
