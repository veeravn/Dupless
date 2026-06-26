import Photos

/// Performs the only mutating operation in MVP 1: moving selected photos to
/// Recently Deleted. PhotoKit itself presents a system confirmation alert for
/// deletions, so this is never silent — and items remain recoverable in Photos.
struct PhotoMutationService {
    enum Result: Equatable {
        case success
        case cancelled
        case failed(String)
    }

    func moveToRecentlyDeleted(_ identifiers: [String]) async -> Result {
        guard !identifiers.isEmpty else { return .success }

        let assets = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard assets.count > 0 else { return .success }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets)
            }
            return .success
        } catch {
            // The user tapping "Don't Allow"/"Cancel" surfaces as an error here.
            if let phError = error as? PHPhotosError, phError.code == .userCancelled {
                return .cancelled
            }
            return .failed(error.localizedDescription)
        }
    }
}
