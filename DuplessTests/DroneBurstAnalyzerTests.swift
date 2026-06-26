import XCTest
@testable import Dupless

final class DroneBurstAnalyzerTests: XCTestCase {
    private let analyzer = DroneBurstAnalyzer()

    /// Hash-only analysis (no feature print) so DuplicateGrouper uses the
    /// deterministic Hamming fallback: identical hash + blocking key → grouped.
    private func analysis(_ id: String, hash: UInt64, sharp: Double = 0.5,
                          favorite: Bool = false, lat: Double? = nil, lon: Double? = nil,
                          aspect: Double = 1.5) -> CachedAnalysis {
        var flags = PhotoFlags.none
        flags.isFavorite = favorite
        return CachedAnalysis(
            id: id, pixelCount: 1000, blockingKey: "k", hash: hash, featurePrintData: nil,
            quality: QualityScores(sharpness: sharp, exposure: 0.5, contrast: 0.5, motionBlur: 0.1),
            flags: flags,
            metadata: PhotoMetadata(creationDate: Date(timeIntervalSince1970: 0),
                                    latitude: lat, longitude: lon, burstIdentifier: nil, aspectRatio: aspect)
        )
    }

    func testRedundantGroupKeepsSharpestAndRemovesRest() {
        let result = analyzer.analyze([
            analysis("a", hash: 0, sharp: 0.9),
            analysis("b", hash: 0, sharp: 0.5),
            analysis("c", hash: 0, sharp: 0.3),
        ])
        XCTAssertEqual(result.recommendedBestShotIds, ["a"])
        XCTAssertTrue(result.protectedUniqueShotIds.isEmpty)
        XCTAssertEqual(Set(result.suggestedRemovalIds), ["b", "c"])
    }

    func testUniqueSingletonIsProtectedNotRemoved() {
        // a,b group (hash 0); c is visually distinct (all bits set) → unique.
        let result = analyzer.analyze([
            analysis("a", hash: 0, sharp: 0.9),
            analysis("b", hash: 0, sharp: 0.4),
            analysis("c", hash: .max, sharp: 0.8),
        ])
        XCTAssertEqual(result.recommendedBestShotIds, ["a"])
        XCTAssertEqual(result.protectedUniqueShotIds, ["c"])
        XCTAssertEqual(result.suggestedRemovalIds, ["b"])
    }

    func testDifferentAltitudeProtectsNonKeeper() {
        let result = analyzer.analyze(
            [analysis("a", hash: 0, sharp: 0.9), analysis("b", hash: 0, sharp: 0.4)],
            altitudes: ["a": 100, "b": 130]
        )
        XCTAssertEqual(result.recommendedBestShotIds, ["a"])
        XCTAssertEqual(result.protectedUniqueShotIds, ["b"])
        XCTAssertTrue(result.suggestedRemovalIds.isEmpty)
    }

    func testDifferentLocationProtectsNonKeeper() {
        let result = analyzer.analyze([
            analysis("a", hash: 0, sharp: 0.9, lat: 37.0, lon: -122.0),
            analysis("b", hash: 0, sharp: 0.4, lat: 37.0006, lon: -122.0), // ~66 m
        ])
        XCTAssertEqual(result.protectedUniqueShotIds, ["b"])
    }

    func testPolicyProtectedPhotoIsNeverRemoved() {
        let result = analyzer.analyze([
            analysis("a", hash: 0, sharp: 0.9),
            analysis("b", hash: 0, sharp: 0.2, favorite: true),
        ])
        XCTAssertEqual(result.recommendedBestShotIds, ["a"])
        XCTAssertEqual(result.protectedUniqueShotIds, ["b"])
        XCTAssertTrue(result.suggestedRemovalIds.isEmpty, "A favorite must never be a removal.")
    }

    func testEmptyInput() {
        let result = analyzer.analyze([])
        XCTAssertTrue(result.recommendedBestShotIds.isEmpty)
        XCTAssertTrue(result.suggestedRemovalIds.isEmpty)
    }
}
