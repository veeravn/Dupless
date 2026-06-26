import XCTest
@testable import Dupless

final class SimilaritySensitivityTests: XCTestCase {
    func testThresholdsIncreaseWithLooseness() {
        XCTAssertLessThan(SimilaritySensitivity.conservative.featureDistanceThreshold,
                          SimilaritySensitivity.balanced.featureDistanceThreshold)
        XCTAssertLessThan(SimilaritySensitivity.balanced.featureDistanceThreshold,
                          SimilaritySensitivity.aggressive.featureDistanceThreshold)
    }

    func testAllCasesHaveDistinctTitles() {
        let titles = Set(SimilaritySensitivity.allCases.map(\.title))
        XCTAssertEqual(titles.count, SimilaritySensitivity.allCases.count)
    }

    func testRawValueRoundTrip() {
        for level in SimilaritySensitivity.allCases {
            XCTAssertEqual(SimilaritySensitivity(rawValue: level.rawValue), level)
        }
    }

    func testHammingPrefilterIsPositive() {
        for level in SimilaritySensitivity.allCases {
            XCTAssertGreaterThan(level.hammingPrefilter, 0)
            XCTAssertLessThanOrEqual(level.hammingPrefilter, 64)
        }
    }
}
