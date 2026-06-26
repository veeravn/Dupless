import XCTest
@testable import Dupless

final class PhotoMetadataTests: XCTestCase {
    func testHelpers() {
        let m = PhotoMetadata(creationDate: nil, latitude: 1, longitude: 2, burstIdentifier: "B", aspectRatio: 1.33)
        XCTAssertTrue(m.hasLocation)
        XCTAssertTrue(m.isBurst)

        XCTAssertFalse(PhotoMetadata.unknown.hasLocation)
        XCTAssertFalse(PhotoMetadata.unknown.isBurst)

        let noGPS = PhotoMetadata(creationDate: .now, latitude: nil, longitude: nil, burstIdentifier: nil, aspectRatio: 1)
        XCTAssertFalse(noGPS.hasLocation)
    }

    func testCodableRoundTrip() throws {
        let m = PhotoMetadata(creationDate: Date(timeIntervalSince1970: 1000),
                              latitude: 37.5, longitude: -122.2, burstIdentifier: "B1", aspectRatio: 1.5)
        let data = try JSONEncoder().encode(m)
        let back = try JSONDecoder().decode(PhotoMetadata.self, from: data)
        XCTAssertEqual(back, m)
    }

    /// Metadata must survive the CachedAnalysis <-> ImageFeatureRecord conversion
    /// so a resumed scan keeps the time/GPS/burst signals for clustering.
    func testCachedAnalysisCarriesMetadataThroughRecord() {
        let meta = PhotoMetadata(creationDate: Date(timeIntervalSince1970: 2000),
                                 latitude: 10, longitude: 20, burstIdentifier: "burst-7", aspectRatio: 1.78)
        let cached = CachedAnalysis(id: "x", pixelCount: 100, blockingKey: "k", hash: 7,
                                    featurePrintData: nil, metadata: meta)
        let record = ImageFeatureRecord(cached: cached)
        XCTAssertEqual(record.metadata, meta)
        XCTAssertEqual(record.cachedAnalysis.metadata, meta)
    }

    func testCachedAnalysisDefaultsToUnknownMetadata() {
        let cached = CachedAnalysis(id: "x", pixelCount: 1, blockingKey: "k", hash: 1, featurePrintData: nil)
        XCTAssertEqual(cached.metadata, .unknown)
    }
}
