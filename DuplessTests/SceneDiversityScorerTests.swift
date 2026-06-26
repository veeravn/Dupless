import XCTest
@testable import CleanShots

final class SceneDiversityScorerTests: XCTestCase {
    private let scorer = SceneDiversityScorer()

    private func meta(lat: Double? = nil, lon: Double? = nil, aspect: Double = 1.5) -> PhotoMetadata {
        PhotoMetadata(creationDate: nil, latitude: lat, longitude: lon, burstIdentifier: nil, aspectRatio: aspect)
    }

    func testDifferentAltitudeIsUnique() {
        XCTAssertTrue(scorer.isUniqueAngle(candidate: meta(), keeper: meta(),
                                           candidateAltitude: 120, keeperAltitude: 100))
    }

    func testSimilarAltitudeIsNotUnique() {
        XCTAssertFalse(scorer.isUniqueAngle(candidate: meta(), keeper: meta(),
                                            candidateAltitude: 101, keeperAltitude: 100))
    }

    func testDifferentLocationIsUnique() {
        // ~55 m apart.
        XCTAssertTrue(scorer.isUniqueAngle(candidate: meta(lat: 37.0005, lon: -122.0),
                                           keeper: meta(lat: 37.0, lon: -122.0),
                                           candidateAltitude: nil, keeperAltitude: nil))
    }

    func testNearbyLocationIsNotUnique() {
        // ~5 m apart.
        XCTAssertFalse(scorer.isUniqueAngle(candidate: meta(lat: 37.00004, lon: -122.0),
                                            keeper: meta(lat: 37.0, lon: -122.0),
                                            candidateAltitude: nil, keeperAltitude: nil))
    }

    func testDifferentFramingIsUnique() {
        XCTAssertTrue(scorer.isUniqueAngle(candidate: meta(aspect: 0.56), keeper: meta(aspect: 1.78),
                                           candidateAltitude: nil, keeperAltitude: nil))
    }

    func testIdenticalIsNotUnique() {
        XCTAssertFalse(scorer.isUniqueAngle(candidate: meta(lat: 37, lon: -122, aspect: 1.5),
                                            keeper: meta(lat: 37, lon: -122, aspect: 1.5),
                                            candidateAltitude: 100, keeperAltitude: 100))
    }

    func testDisabledNeverProtects() {
        var s = SceneDiversityScorer(); s.config.enabled = false
        XCTAssertFalse(s.isUniqueAngle(candidate: meta(), keeper: meta(),
                                       candidateAltitude: 200, keeperAltitude: 100))
    }
}
