import XCTest
@testable import Dupless

/// The model can over-eagerly map vague recency ("recent") onto a concrete range
/// like last week. `corroboratedDatePhrase` only honors a date when the request
/// actually contains that phrase's keyword.
final class DateCorroborationTests: XCTestCase {
    private func corroborate(_ phrase: DatePhrase?, _ text: String) -> DatePhrase? {
        FoundationModelScanParser.corroboratedDatePhrase(phrase, in: text)
    }

    func testVagueRecencyDropsTheDate() {
        XCTAssertNil(corroborate(.lastWeek, "scan photos from recent mall of america trip"))
        XCTAssertNil(corroborate(.lastMonth, "find my beach photos"))
    }

    func testExplicitPhraseIsKept() {
        XCTAssertEqual(corroborate(.lastWeek, "duplicates from last week"), .lastWeek)
        XCTAssertEqual(corroborate(.lastMonth, "photos from the past month"), .lastMonth)
        XCTAssertEqual(corroborate(.yesterday, "yesterday's screenshots"), .yesterday)
        XCTAssertEqual(corroborate(.lastWeekend, "this past weekend"), .lastWeekend)
        XCTAssertEqual(corroborate(.lastYear, "last year's trip"), .lastYear)
        XCTAssertEqual(corroborate(.today, "today's photos"), .today)
    }

    func testNoPhraseStaysNil() {
        XCTAssertNil(corroborate(nil, "last week"))
    }

    func testKeywordMatchIsCaseInsensitive() {
        XCTAssertEqual(corroborate(.lastMonth, "Photos From Last MONTH"), .lastMonth)
    }
}
