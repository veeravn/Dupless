import XCTest
@testable import Dupless

final class LocationMatchingTests: XCTestCase {
    private let matcher = PhotoLocationMatcher()

    func testMatchesAcrossPlaceFields() {
        XCTAssertTrue(matcher.matches(query: "mall of america",
                                      placeFields: ["Mall of America", "Bloomington", "Minnesota"]))
    }

    func testRequiresAllTokensSoLoneWordsDoNotMatch() {
        // "America" alone must not satisfy "mall of america".
        XCTAssertFalse(matcher.matches(query: "mall of america", placeFields: ["America"]))
    }

    func testUnrelatedPlaceDoesNotMatch() {
        XCTAssertFalse(matcher.matches(query: "mall of america",
                                       placeFields: ["Yellowstone National Park", "Wyoming"]))
    }

    func testTokensCanMatchDifferentFields() {
        XCTAssertTrue(matcher.matches(query: "mall america",
                                      placeFields: ["Mall", "America"]))
    }

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(matcher.matches(query: "", placeFields: []))
    }

    // MARK: - Plumbing

    func testLocationQueryFlowsIntoOptions() {
        let command = AIScanCommand(target: .recent(limit: 300), mode: .balanced,
                                    locationQuery: "mall of america")
        XCTAssertEqual(command.toScanRequest().options.locationQuery, "mall of america")
    }

    func testSummaryNamesThePlace() {
        let command = AIScanCommand(target: .recent(limit: 300), mode: .balanced,
                                    includeScreenshots: true, locationQuery: "mall of america")
        XCTAssertEqual(ParsedScan.summary(for: command, datePhrase: nil),
                       "Balanced scan of your 300 most recent photos at mall of america, including screenshots.")
    }
}
