import Foundation
import ImageIO

/// Reads GPS altitude (in meters) from an image's EXIF/GPS metadata.
///
/// Pure over image data — no PhotoKit — so it's unit-testable with generated
/// images. This is intentionally the only part of the pipeline that touches full
/// image metadata; it is invoked lazily by drone/burst scene-diversity scoring on
/// the small subset of photos already clustered as drone-like, never across the
/// whole library. `CGImageSourceCopyPropertiesAtIndex` reads metadata only — it
/// does not decode pixels.
///
/// Returns `nil` when no GPS altitude is present. Callers treat a missing
/// altitude as "no signal" and fall back to time + visual + burst grouping.
enum PhotoAltitudeReader {
    /// Parses altitude from encoded image data (JPEG/HEIC/etc.).
    static func altitude(fromImageData data: Data) -> Double? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return altitude(from: source)
    }

    /// Parses altitude from an existing image source (metadata only).
    static func altitude(from source: CGImageSource) -> Double? {
        guard
            let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
            let meters = number(gps[kCGImagePropertyGPSAltitude])
        else { return nil }

        // GPSAltitudeRef == 1 means the altitude is below sea level.
        if let ref = number(gps[kCGImagePropertyGPSAltitudeRef]), ref == 1 {
            return -meters
        }
        return meters
    }

    private static func number(_ value: Any?) -> Double? {
        if let n = value as? NSNumber { return n.doubleValue }
        if let d = value as? Double { return d }
        if let s = value as? String { return Double(s) }
        return nil
    }
}
