import Foundation

/// Supplies GPS altitude for a set of assets. Abstracted so the scanner is
/// testable without PhotoKit; the real implementation is `PhotoAltitudeService`.
protocol AltitudeProviding: Sendable {
    func altitudes(for identifiers: [String]) async -> [String: Double]
}

// PhotoAltitudeService declares its AltitudeProviding conformance in its own
// file — a Sendable-inheriting conformance must live with the type in Swift 6.

/// Never returns altitude — the default for non-drone scans and tests.
struct NoAltitudeProvider: AltitudeProviding {
    func altitudes(for identifiers: [String]) async -> [String: Double] { [:] }
}

/// One session cluster paired with its redundancy decision.
struct SessionClusterOutcome: Sendable, Equatable {
    let cluster: SessionCluster
    let result: SessionClusterResult
}

/// Orchestrates a drone/burst scan over already-analyzed photos: cluster by
/// session, then find redundant sequences and best shots per cluster. Altitude
/// is fetched lazily and only for drone-like clusters — the only place the
/// pipeline reads full image metadata.
struct DroneBurstScanner {
    var clusterer: SessionClusterer
    var analyzer: DroneBurstAnalyzer
    let altitudeProvider: AltitudeProviding

    init(
        clusterer: SessionClusterer = SessionClusterer(),
        analyzer: DroneBurstAnalyzer = DroneBurstAnalyzer(),
        altitudeProvider: AltitudeProviding = NoAltitudeProvider()
    ) {
        self.clusterer = clusterer
        self.analyzer = analyzer
        self.altitudeProvider = altitudeProvider
    }

    func scan(_ analyses: [CachedAnalysis]) async -> [SessionClusterOutcome] {
        let byID = Dictionary(uniqueKeysWithValues: analyses.map { ($0.id, $0) })
        let clusters = clusterer.cluster(analyses.map(SessionPhoto.init))

        var outcomes: [SessionClusterOutcome] = []
        for cluster in clusters {
            let members = cluster.memberIdentifiers.compactMap { byID[$0] }
            // Lazy altitude: only drone-like clusters pay the EXIF cost.
            let altitudes = cluster.sessionType == .droneLike
                ? await altitudeProvider.altitudes(for: cluster.memberIdentifiers)
                : [:]
            let result = analyzer.analyze(members, altitudes: altitudes)
            outcomes.append(SessionClusterOutcome(cluster: cluster, result: result))
        }
        return outcomes
    }

    /// Maps an outcome to its persistable record.
    func record(from outcome: SessionClusterOutcome) -> SessionClusterRecord {
        SessionClusterRecord(
            assetIdentifiers: outcome.cluster.memberIdentifiers,
            sessionType: outcome.cluster.sessionType,
            startDate: outcome.cluster.startDate,
            endDate: outcome.cluster.endDate,
            locationBucket: outcome.cluster.locationBucket,
            recommendedBestShotIds: outcome.result.recommendedBestShotIds,
            protectedUniqueShotIds: outcome.result.protectedUniqueShotIds
        )
    }
}
