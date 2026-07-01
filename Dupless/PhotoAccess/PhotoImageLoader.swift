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

    /// Edge for the face-identity render. Larger than the analysis thumbnail so a
    /// face in a group shot is ~80–200px rather than ~15–40px — enough for the
    /// per-face feature print to actually distinguish people (the 256px thumbnail
    /// can't; measured).
    static let faceSourceSize = CGSize(width: 1024, height: 1024)

    /// A higher-resolution render used ONLY to crop faces for identity matching,
    /// requested only for photos that already have a detected face. Not cached
    /// (one transient use during analysis, and at ~1024px these are too big to keep
    /// 400 of).
    ///
    /// Allows an iCloud fetch (`isNetworkAccessAllowed = true`): an optimized photo
    /// whose on-device copy is too small can't otherwise yield usable face crops,
    /// which silently disabled identity matching and merged different people with
    /// the same head count. PHImageManager still serves a local copy when one is
    /// adequate, so only not-downloaded face photos incur a fetch — the first scan
    /// of a heavily-optimized library is slower as a result. The fetch pulls the
    /// user's own photo from their own iCloud; nothing is sent anywhere.
    func faceSource(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: Self.faceSourceSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                // .highQualityFormat delivers a single result; take whatever image
                // arrives (even if flagged degraded) so we never hang, and resume
                // nil only when none could be produced.
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }
    }

    /// Larger, display-quality image for the full-screen inspector. Unlike
    /// `thumbnail`, this allows an iCloud download — the user explicitly opened
    /// the photo for a closer look — and isn't cached, to avoid evicting the
    /// analysis thumbnails. Capped at a memory-safe edge, not the full original.
    static let inspectorSize = CGSize(width: 2048, height: 2048)

    func inspectorImage(for asset: PHAsset) async -> UIImage? {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        return await withCheckedContinuation { continuation in
            var didResume = false
            imageManager.requestImage(
                for: asset,
                targetSize: Self.inspectorSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                guard !didResume else { return }
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if let image, !isDegraded {
                    didResume = true
                    continuation.resume(returning: image)
                } else if image == nil {
                    didResume = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func cacheKey(_ id: String, _ size: CGSize) -> NSString {
        "\(id)-\(Int(size.width))x\(Int(size.height))" as NSString
    }
}
