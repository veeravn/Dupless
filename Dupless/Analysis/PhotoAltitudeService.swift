import Foundation
import Photos

/// Best-effort, lazy altitude lookup for a small set of assets — the drone-like
/// subset identified during clustering. Requests the original image data locally
/// and parses EXIF via `PhotoAltitudeReader`.
///
/// Deliberately cheap and offline: network access is disabled, so assets that
/// aren't already on-device simply return no altitude (no iCloud downloads, no
/// added scan latency for the rest of the library). Assets without GPS altitude
/// are omitted from the result — "no GPS" is the expected default, not an error.
struct PhotoAltitudeService: AltitudeProviding {
    func altitudes(for identifiers: [String]) async -> [String: Double] {
        guard !identifiers.isEmpty else { return [:] }

        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetch.count)
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false   // stay on-device; no iCloud downloads
        options.isSynchronous = false
        options.deliveryMode = .fastFormat       // we only need the file's metadata

        // The drone-like subset is small, so a simple sequential pass keeps this
        // free of PHAsset Sendable concerns.
        var result: [String: Double] = [:]
        for asset in assets {
            if let data = await Self.imageData(for: asset, options: options),
               let altitude = PhotoAltitudeReader.altitude(fromImageData: data) {
                result[asset.localIdentifier] = altitude
            }
        }
        return result
    }

    private static func imageData(for asset: PHAsset, options: PHImageRequestOptions) async -> Data? {
        await withCheckedContinuation { continuation in
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                continuation.resume(returning: data)
            }
        }
    }
}
