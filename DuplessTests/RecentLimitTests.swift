import XCTest
@testable import Dupless

/// An undated scan caps at the default recent window, but a named place widens
/// it: location is a post-fetch filter, so the candidate set must reach further
/// back to catch an older trip the user didn't date.
final class RecentLimitTests: XCTestCase {
    func testUndatedScanUsesDefaultLimit() {
        XCTAssertEqual(FoundationModelScanParser.recentLimit(hasLocationQuery: false),
                       AIScanCommand.defaultRecentLimit)
    }

    func testPlaceQueryWidensTheWindow() {
        XCTAssertEqual(FoundationModelScanParser.recentLimit(hasLocationQuery: true),
                       AIScanCommand.placeScopedRecentLimit)
    }

    func testPlaceWindowIsWiderThanDefault() {
        XCTAssertGreaterThan(AIScanCommand.placeScopedRecentLimit,
                             AIScanCommand.defaultRecentLimit)
    }
}
