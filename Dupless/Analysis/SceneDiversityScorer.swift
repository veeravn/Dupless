import Foundation

/// Tunable thresholds for what counts as a meaningfully different angle.
struct SceneDiversityConfig: Sendable {
    /// Altitude difference (m) that marks a different drone pass.
    var altitudeMeters: Double = 8
    /// Horizontal separation (m) that marks a different viewpoint.
    var locationMeters: Double = 30
    /// Aspect-ratio difference that marks different framing/composition.
    var aspectDelta: Double = 0.3
    /// When off, no photo is protected as a unique angle (user can lower it).
    var enabled: Bool = true

    static let `default` = SceneDiversityConfig()
}

/// Decides whether a photo contributes unique coverage versus a group's keeper,
/// so drone/burst cleanup never removes a meaningfully different angle (the
/// spec's #1 risk mitigation). Pure over metadata + optional altitudes.
struct SceneDiversityScorer {
    var config: SceneDiversityConfig = .default

    func isUniqueAngle(
        candidate: PhotoMetadata,
        keeper: PhotoMetadata,
        candidateAltitude: Double?,
        keeperAltitude: Double?
    ) -> Bool {
        guard config.enabled else { return false }

        // Different altitude — a higher/lower drone pass of the same subject.
        if let ca = candidateAltitude, let ka = keeperAltitude, abs(ca - ka) >= config.altitudeMeters {
            return true
        }
        // Different horizontal position — a different vantage point.
        if let clat = candidate.latitude, let clon = candidate.longitude,
           let klat = keeper.latitude, let klon = keeper.longitude,
           GeoDistance.meters(lat1: clat, lon1: clon, lat2: klat, lon2: klon) >= config.locationMeters {
            return true
        }
        // Different framing/composition.
        if candidate.aspectRatio > 0, keeper.aspectRatio > 0,
           abs(candidate.aspectRatio - keeper.aspectRatio) >= config.aspectDelta {
            return true
        }
        return false
    }
}
