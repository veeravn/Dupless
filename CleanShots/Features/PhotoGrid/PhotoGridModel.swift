import Photos
import SwiftUI

/// Backs PhotoGridView: fetches recent assets and lazily loads their thumbnails.
/// This is the Milestone 1 proof that PhotoKit access works end-to-end.
@MainActor
@Observable
final class PhotoGridModel {
    private(set) var assets: [PHAsset] = []
    private let fetcher = PhotoAssetFetcher()
    private let loader = PhotoImageLoader()

    func load(scope: ScanScope = .recent(limit: 300)) {
        let result = fetcher.fetchAssets(scope: scope, options: ScanOptions(includeScreenshots: true, excludeFavorites: false))
        var fetched: [PHAsset] = []
        fetched.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in fetched.append(asset) }
        assets = fetched
    }

    func thumbnail(for asset: PHAsset) async -> UIImage? {
        await loader.thumbnail(for: asset)
    }
}
