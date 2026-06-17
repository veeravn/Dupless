import Photos
import SwiftUI

/// Square thumbnail for a PHAsset, loaded on-device via the shared loader.
struct AssetThumbnailView: View {
    let asset: PHAsset
    var targetSize: CGSize = PhotoImageLoader.thumbnailSize

    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemBackground)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    ProgressView()
                }
            }
            .clipped()
            .task(id: asset.localIdentifier) {
                image = await PhotoImageLoader.shared.thumbnail(for: asset, targetSize: targetSize)
            }
    }
}

/// Resolves a single PHAsset from a local identifier (cheap synchronous fetch).
enum AssetResolver {
    static func asset(for identifier: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject
    }

    static func assets(for identifiers: [String]) -> [PHAsset] {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in assets.append(asset) }
        return assets
    }
}
