import Photos
import PhotosUI
import SwiftUI

/// Observable wrapper around PhotoKit authorization state.
///
/// Handles the full/limited/denied distinction the MVP 1 spec calls out and
/// keeps a published value the UI can react to, including changes made while
/// the app is backgrounded (e.g. the user revokes access in Settings).
@MainActor
@Observable
final class PhotoAuthorizationManager {
    enum Status: Equatable {
        case notDetermined
        case authorized
        case limited
        case denied
        case restricted

        var grantsAccess: Bool { self == .authorized || self == .limited }
    }

    private(set) var status: Status

    /// Registered for the app's lifetime. Its sole job is to keep PhotoKit's
    /// per-process library snapshot fresh — without a registered change observer,
    /// `PHAsset.fetchAssets` returns a stale snapshot, so photos captured after
    /// launch don't appear in a scan (recent OR date-range) until the system
    /// eventually refreshes the process. This is the "rescan misses new photos" fix.
    private let libraryObserver = PhotoLibraryObserver()

    init() {
        status = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// Re-reads the current system status. Call on `scenePhase` becoming active
    /// to recover from permission changes made outside the app.
    func refresh() {
        status = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    /// Prompts for read/write access. Safe to call when already determined —
    /// PhotoKit returns the existing status without re-prompting.
    func requestAccess() async {
        let result = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        status = Self.map(result)
    }

    /// Presents the system limited-library picker so the user can add photos.
    func presentLimitedLibraryPicker(from viewController: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    private static func map(_ status: PHAuthorizationStatus) -> Status {
        switch status {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }
}

/// Registers as a `PHPhotoLibraryChangeObserver` so PhotoKit keeps this process's
/// library snapshot up to date. Registration alone is the fix — a fresh
/// `PHAsset.fetchAssets` then reflects photos added since launch. The callback is
/// intentionally a no-op: the scan re-fetches on demand, so there's no held
/// `PHFetchResult` to update here.
private final class PhotoLibraryObserver: NSObject, PHPhotoLibraryChangeObserver {
    override init() {
        super.init()
        PHPhotoLibrary.shared().register(self)
    }

    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }

    func photoLibraryDidChange(_ changeInstance: PHChange) {}
}
