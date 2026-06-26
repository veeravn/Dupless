import XCTest
@testable import CleanShots

final class SessionClustererTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_000_000)
    private let clusterer = SessionClusterer()

    private func photo(_ id: String, at secondsAfter: TimeInterval,
                       lat: Double? = nil, lon: Double? = nil, burst: String? = nil) -> SessionPhoto {
        SessionPhoto(id: id, metadata: PhotoMetadata(
            creationDate: base.addingTimeInterval(secondsAfter),
            latitude: lat, longitude: lon, burstIdentifier: burst, aspectRatio: 1.5
        ))
    }

    // MARK: - Type classification

    func testBurstFromSharedIdentifier() {
        let photos = [photo("a", at: 0, burst: "B"), photo("b", at: 1, burst: "B"), photo("c", at: 2, burst: "B")]
        let clusters = clusterer.cluster(photos)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].sessionType, .burst)
        XCTAssertEqual(clusters[0].memberIdentifiers, ["a", "b", "c"])
    }

    func testBurstFromTightTimingWithoutIdentifier() {
        let photos = [photo("a", at: 0), photo("b", at: 10), photo("c", at: 25)] // span 25s
        XCTAssertEqual(clusterer.cluster(photos).first?.sessionType, .burst)
    }

    func testDroneLikeWhenSpreadWithGPS() {
        // 0–15 min, all geotagged near the same place → drone-like.
        let photos = [
            photo("a", at: 0, lat: 37.1234, lon: -122.6543),
            photo("b", at: 300, lat: 37.1234, lon: -122.6543),
            photo("c", at: 600, lat: 37.1235, lon: -122.6543),
            photo("d", at: 900, lat: 37.1234, lon: -122.6544),
        ]
        let clusters = clusterer.cluster(photos)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].sessionType, .droneLike)
        XCTAssertEqual(clusters[0].locationBucket, "37.1234,-122.6543")
    }

    func testPhotoSessionWhenSpreadWithoutGPS() {
        // 0–25 min, no GPS → photo session (not drone-like).
        let photos = [photo("a", at: 0), photo("b", at: 600), photo("c", at: 1500)]
        XCTAssertEqual(clusterer.cluster(photos).first?.sessionType, .photoSession)
    }

    func testEventForLongContinuousSpan() {
        // Gaps of 25 min (≤ session gap) but total span 75 min → event.
        let photos = [photo("a", at: 0), photo("b", at: 1500), photo("c", at: 3000), photo("d", at: 4500)]
        let clusters = clusterer.cluster(photos)
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].sessionType, .event)
    }

    // MARK: - Splitting

    func testSplitsWhenTimeGapExceedsSessionGap() {
        let photos = [photo("a", at: 0), photo("b", at: 3600)] // 60 min gap
        let clusters = clusterer.cluster(photos)
        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map(\.memberIdentifiers), [["a"], ["b"]])
    }

    func testSplitsWhenLocationJumps() {
        // Close in time, but different places → different sessions.
        let photos = [
            photo("a", at: 0, lat: 37.1, lon: -122.1),
            photo("b", at: 60, lat: 37.5, lon: -122.5),
        ]
        XCTAssertEqual(clusterer.cluster(photos).count, 2)
    }

    // MARK: - Edges

    func testUndatedPhotosAreDropped() {
        let dated = photo("a", at: 0)
        let undated = SessionPhoto(id: "z", metadata: .unknown)
        let clusters = clusterer.cluster([dated, undated])
        XCTAssertEqual(clusters.count, 1)
        XCTAssertEqual(clusters[0].memberIdentifiers, ["a"])
    }

    func testEmptyInput() {
        XCTAssertTrue(clusterer.cluster([]).isEmpty)
    }

    func testStartAndEndDatesSpanCluster() {
        let photos = [photo("a", at: 100), photo("b", at: 50), photo("c", at: 200)]
        let cluster = clusterer.cluster(photos)[0]
        XCTAssertEqual(cluster.startDate, base.addingTimeInterval(50))
        XCTAssertEqual(cluster.endDate, base.addingTimeInterval(200))
    }
}
