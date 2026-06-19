import XCTest
@testable import CleanShots

final class LocationBucketTests: XCTestCase {
    func testRoundsToPrecision() {
        XCTAssertEqual(LocationBucket.bucket(latitude: 37.123456, longitude: -122.654321, precision: 4),
                       "37.1235,-122.6543")
    }

    func testNilWhenCoordinateMissing() {
        XCTAssertNil(LocationBucket.bucket(latitude: nil, longitude: -122.0))
        XCTAssertNil(LocationBucket.bucket(latitude: 37.0, longitude: nil))
        XCTAssertNil(LocationBucket.bucket(.unknown))
    }

    func testNearbyCoordinatesShareCoarseBucket() {
        let a = LocationBucket.bucket(latitude: 37.12341, longitude: -122.65432, precision: 3)
        let b = LocationBucket.bucket(latitude: 37.12349, longitude: -122.65431, precision: 3)
        XCTAssertEqual(a, b)
    }

    func testFarCoordinatesDifferentBucket() {
        let a = LocationBucket.bucket(latitude: 37.1, longitude: -122.1, precision: 3)
        let b = LocationBucket.bucket(latitude: 37.5, longitude: -122.5, precision: 3)
        XCTAssertNotEqual(a, b)
    }
}
