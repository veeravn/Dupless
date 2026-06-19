import Foundation

/// Minimal input for session clustering: an asset id plus the cheap metadata
/// signals captured during analysis. Decoupled from `CachedAnalysis` so the
/// clusterer is trivially testable with synthetic data.
struct SessionPhoto: Sendable, Equatable {
    let id: String
    let metadata: PhotoMetadata

    init(id: String, metadata: PhotoMetadata) {
        self.id = id
        self.metadata = metadata
    }

    init(_ cached: CachedAnalysis) {
        self.id = cached.id
        self.metadata = cached.metadata
    }
}

/// A clustered photo session (value type; maps to `SessionClusterRecord` once the
/// best shots / protected angles are decided in Step 2).
struct SessionCluster: Sendable, Equatable {
    let memberIdentifiers: [String]
    let sessionType: SessionType
    let startDate: Date
    let endDate: Date
    let locationBucket: String?

    var span: TimeInterval { endDate.timeIntervalSince(startDate) }
}

/// Tunable thresholds, mirroring the spec's suggested time windows.
struct SessionClusteringConfig: Sendable {
    /// Split into a new session when the gap between consecutive shots exceeds this.
    var sessionGap: TimeInterval = 30 * 60
    /// ≤ this total span → burst sequence.
    var burstSpan: TimeInterval = 30
    /// ≤ this total span, with GPS → drone-like sequence.
    var droneSpan: TimeInterval = 20 * 60
    /// ≤ this total span → photo session (longer continuous spans become events).
    var sessionSpan: TimeInterval = 30 * 60
    /// Max distance between consecutive geotagged shots to stay in one session.
    var proximityMeters: Double = 150
    /// Decimal places used for the stored location label (4 ≈ 11 m).
    var labelPrecision: Int = 4

    static let `default` = SessionClusteringConfig()
}

/// Groups photos into time/location/burst sessions, then labels each by type.
/// Pure and deterministic — no PhotoKit. GPS-absent input falls back to pure
/// time sessionization, per the spec's mitigation.
struct SessionClusterer {
    var config: SessionClusteringConfig

    init(config: SessionClusteringConfig = .default) {
        self.config = config
    }

    func cluster(_ photos: [SessionPhoto]) -> [SessionCluster] {
        // Only time-stamped photos can be sequenced; undated ones can't belong to
        // a session and are dropped (they aren't redundant sequences).
        let timed = photos
            .filter { $0.metadata.creationDate != nil }
            .sorted { $0.metadata.creationDate! < $1.metadata.creationDate! }
        guard !timed.isEmpty else { return [] }

        var clusters: [[SessionPhoto]] = []
        var current: [SessionPhoto] = [timed[0]]
        for next in timed.dropFirst() {
            if continuous(prev: current.last!, next: next) {
                current.append(next)
            } else {
                clusters.append(current)
                current = [next]
            }
        }
        clusters.append(current)

        return clusters.map(makeCluster)
    }

    // MARK: - Continuity

    /// Two consecutive shots stay in the same session when they're close in time
    /// and (if both geotagged) in the same coarse location bucket.
    private func continuous(prev: SessionPhoto, next: SessionPhoto) -> Bool {
        guard let pd = prev.metadata.creationDate, let nd = next.metadata.creationDate else { return false }
        if nd.timeIntervalSince(pd) > config.sessionGap { return false }
        if let plat = prev.metadata.latitude, let plon = prev.metadata.longitude,
           let nlat = next.metadata.latitude, let nlon = next.metadata.longitude {
            let distance = GeoDistance.meters(lat1: plat, lon1: plon, lat2: nlat, lon2: nlon)
            if distance > config.proximityMeters { return false }
        }
        return true
    }

    // MARK: - Build & classify

    private func makeCluster(_ members: [SessionPhoto]) -> SessionCluster {
        let dates = members.compactMap { $0.metadata.creationDate }.sorted()
        let start = dates.first ?? .now
        let end = dates.last ?? start
        let bucket = members.lazy
            .compactMap { LocationBucket.bucket($0.metadata, precision: config.labelPrecision) }
            .first
        return SessionCluster(
            memberIdentifiers: members.map(\.id),
            sessionType: classify(members, span: end.timeIntervalSince(start)),
            startDate: start,
            endDate: end,
            locationBucket: bucket
        )
    }

    /// Labels a cluster. Order matters: burst (tightest) → drone-like (GPS) →
    /// session → event (longest). We never assert "drone", only "drone-like".
    func classify(_ members: [SessionPhoto], span: TimeInterval) -> SessionType {
        let count = members.count
        let burstIDs = Set(members.compactMap { $0.metadata.burstIdentifier })
        let sharedBurst = burstIDs.count == 1 && members.allSatisfy { $0.metadata.isBurst }
        let hasGPS = members.contains { $0.metadata.hasLocation }

        if count >= 2, sharedBurst || span <= config.burstSpan { return .burst }
        if count >= 2, hasGPS, span <= config.droneSpan { return .droneLike }
        if span <= config.sessionSpan { return .photoSession }
        return .event
    }
}
