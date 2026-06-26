import Foundation

/// Rounds GPS coordinates into a coarse "same place" bucket. Two shots in the
/// same bucket are treated as the same location for session clustering. Pure and
/// deterministic; returns nil when a coordinate is missing (no-GPS fallback).
///
/// Precision is decimal places of lat/lon: 4 ≈ 11 m (stored on the record), 3 ≈
/// 110 m (used for clustering proximity so a drone pass stays together but a
/// different place splits).
enum LocationBucket {
    static func bucket(latitude: Double?, longitude: Double?, precision: Int = 4) -> String? {
        guard let latitude, let longitude else { return nil }
        let factor = pow(10.0, Double(precision))
        let lat = (latitude * factor).rounded() / factor
        let lon = (longitude * factor).rounded() / factor
        return String(format: "%.\(precision)f,%.\(precision)f", lat, lon)
    }

    static func bucket(_ metadata: PhotoMetadata, precision: Int = 4) -> String? {
        bucket(latitude: metadata.latitude, longitude: metadata.longitude, precision: precision)
    }
}

/// Great-circle distance between coordinates. Used for "same place" proximity in
/// clustering — distance-based rather than bucket-equality, so a drone pass whose
/// coordinates drift slightly doesn't fragment at bucket boundaries.
enum GeoDistance {
    /// Meters between two lat/lon points (haversine).
    static func meters(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6_371_000.0
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * atan2(sqrt(a), sqrt(1 - a))
    }
}
