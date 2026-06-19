import XCTest
@testable import CleanShots

/// Records which ids altitude was requested for, and returns a canned map.
private final class StubAltitudeProvider: AltitudeProviding, @unchecked Sendable {
    let map: [String: Double]
    private(set) var requestedIds: [String] = []
    init(_ map: [String: Double] = [:]) { self.map = map }
    func altitudes(for identifiers: [String]) async -> [String: Double] {
        requestedIds.append(contentsOf: identifiers)
        return map.filter { identifiers.contains($0.key) }
    }
}

final class DroneBurstScannerTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)

    private func analysis(_ id: String, at secs: Double, hash: UInt64 = 0, sharp: Double = 0.5,
                          lat: Double? = nil, lon: Double? = nil, burst: String? = nil) -> CachedAnalysis {
        CachedAnalysis(
            id: id, pixelCount: 1000, blockingKey: "k", hash: hash, featurePrintData: nil,
            quality: QualityScores(sharpness: sharp, exposure: 0.5, contrast: 0.5, motionBlur: 0.1),
            flags: .none,
            metadata: PhotoMetadata(creationDate: base.addingTimeInterval(secs),
                                    latitude: lat, longitude: lon, burstIdentifier: burst, aspectRatio: 1.5)
        )
    }

    func testDroneLikeClusterFetchesAltitudeAndProtectsByIt() async {
        let provider = StubAltitudeProvider(["a": 100, "b": 130, "c": 100])
        let scanner = DroneBurstScanner(altitudeProvider: provider)

        // 0–10 min, geotagged, visually identical → one drone-like cluster.
        let outcomes = await scanner.scan([
            analysis("a", at: 0, sharp: 0.9, lat: 37.0, lon: -122.0),
            analysis("b", at: 300, sharp: 0.4, lat: 37.0, lon: -122.0),
            analysis("c", at: 600, sharp: 0.4, lat: 37.0, lon: -122.0),
        ])

        XCTAssertEqual(outcomes.count, 1)
        XCTAssertEqual(outcomes[0].cluster.sessionType, .droneLike)
        XCTAssertEqual(Set(provider.requestedIds), ["a", "b", "c"], "Altitude must be fetched for drone-like clusters.")

        let result = outcomes[0].result
        XCTAssertEqual(result.recommendedBestShotIds, ["a"])
        XCTAssertTrue(result.protectedUniqueShotIds.contains("b"), "b is at a different altitude → unique.")
        XCTAssertEqual(result.suggestedRemovalIds, ["c"])
    }

    func testBurstClusterDoesNotFetchAltitude() async {
        let provider = StubAltitudeProvider(["a": 100, "b": 200])
        let scanner = DroneBurstScanner(altitudeProvider: provider)

        let outcomes = await scanner.scan([
            analysis("a", at: 0, sharp: 0.9, burst: "B"),
            analysis("b", at: 1, sharp: 0.4, burst: "B"),
        ])

        XCTAssertEqual(outcomes[0].cluster.sessionType, .burst)
        XCTAssertTrue(provider.requestedIds.isEmpty, "Only drone-like clusters pay the altitude cost.")
        XCTAssertEqual(outcomes[0].result.recommendedBestShotIds, ["a"])
    }

    func testRecordMapping() async {
        let scanner = DroneBurstScanner()
        let outcomes = await scanner.scan([
            analysis("a", at: 0, sharp: 0.9, burst: "B"),
            analysis("b", at: 1, sharp: 0.4, burst: "B"),
        ])
        let record = scanner.record(from: outcomes[0])
        XCTAssertEqual(record.sessionType, .burst)
        XCTAssertEqual(record.assetIdentifiers, ["a", "b"])
        XCTAssertEqual(record.recommendedBestShotIds, ["a"])
    }
}
