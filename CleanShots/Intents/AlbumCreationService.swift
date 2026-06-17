import Photos

/// Creates a Photos album from a set of assets (used to save best-shots keepers
/// from Siri). Creating an album is additive and reversible — never deletes.
struct AlbumCreationService {
    enum Result: Equatable {
        case success(count: Int)
        case empty
        case failed(String)
    }

    func createAlbum(named name: String, assetIdentifiers: [String]) async -> Result {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: assetIdentifiers, options: nil)
        guard assets.count > 0 else { return .empty }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: name)
                request.addAssets(assets)
            }
            return .success(count: assets.count)
        } catch {
            return .failed(error.localizedDescription)
        }
    }
}
