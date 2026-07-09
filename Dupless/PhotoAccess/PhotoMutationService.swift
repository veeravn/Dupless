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

    /// Shown when PhotoKit refuses to delete some assets — which surfaces as
    /// PHPhotosErrorChangeNotSupported (3300). These are asset types the user can't
    /// delete on device: a Shared Album, a shared iCloud library they don't own, My
    /// Photo Stream, or an album synced from a computer. Even a *regular* album can
    /// contain such assets, which is why album mode hits this more than the camera
    /// roll.
    private static let notDeletableMessage =
        "Some of these photos can’t be deleted from here — they may be in a Shared Album, a shared iCloud library, or synced from a computer. You can remove them in the Photos app."

    func moveToRecentlyDeleted(_ identifiers: [String]) async -> Result {
        guard !identifiers.isEmpty else { return .success }

        let fetched = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetched.count > 0 else { return .success }

        // Keep only assets that actually support deletion. Non-deletable assets
        // (cloud-shared, shared-library the user doesn't own, My Photo Stream, or
        // synced from a computer) — which even a regular album can contain — fail
        // `deleteAssets`, and including even one fails the WHOLE batch with
        // PHPhotosErrorChangeNotSupported (3300). Filtering deletes what we can.
        var deletable: [PHAsset] = []
        fetched.enumerateObjects { asset, _, _ in
            if asset.canPerform(.delete) { deletable.append(asset) }
        }

        guard !deletable.isEmpty else { return .failed(Self.notDeletableMessage) }

        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(deletable as NSArray)
            }
            return .success
        } catch {
            guard let phError = error as? PHPhotosError else {
                return .failed(error.localizedDescription)
            }
            switch phError.code {
            // The user tapping "Don't Allow"/"Cancel" surfaces as an error here.
            case .userCancelled:
                return .cancelled
            // Belt-and-suspenders: a non-deletable asset that slipped past the
            // filter surfaces here rather than as an opaque "error 3300".
            case .changeNotSupported:
                return .failed(Self.notDeletableMessage)
            default:
                return .failed(error.localizedDescription)
            }
        }
    }
}
