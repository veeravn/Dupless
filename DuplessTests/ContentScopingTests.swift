import XCTest
@testable import CleanShots

final class ContentScopingTests: XCTestCase {
    private let classifier = PhotoContentClassifier()

    // MARK: - Label matching

    func testQueryMatchesViaSubstringLabel() {
        XCTAssertTrue(classifier.matches(query: "birthday", labels: ["birthday_cake", "people"]))
    }

    func testNonMatchingLabelsReturnFalse() {
        XCTAssertFalse(classifier.matches(query: "dog", labels: ["cat", "sofa"]))
    }

    func testEmptyQueryMatchesEverything() {
        XCTAssertTrue(classifier.matches(query: "", labels: ["anything"]))
        XCTAssertTrue(classifier.matches(query: "   ", labels: []))
    }

    func testShortTokensAreIgnored() {
        // "a" / "of" are < 3 letters → no usable tokens → matches everything.
        XCTAssertTrue(classifier.matches(query: "a of", labels: ["unrelated"]))
    }

    func testLabelSubstringOfTokenAlsoMatches() {
        XCTAssertTrue(classifier.matches(query: "birthdays", labels: ["birthday"]))
    }

    // MARK: - Summary reflects the content theme

    func testSummaryIncludesContentForDateRange() {
        let command = AIScanCommand(
            target: .dateRange(start: .now, end: .now),
            mode: .balanced, includeScreenshots: false, contentQuery: "birthday"
        )
        let summary = ParsedScan.summary(for: command, datePhrase: .lastWeek)
        XCTAssertEqual(summary, "Balanced scan of birthday photos from last week, excluding screenshots.")
    }

    func testSummaryOmitsContentWhenNil() {
        let command = AIScanCommand(
            target: .recent(limit: 300), mode: .balanced, includeScreenshots: true, contentQuery: nil
        )
        let summary = ParsedScan.summary(for: command, datePhrase: nil)
        XCTAssertEqual(summary, "Balanced scan of your 300 most recent photos, including screenshots.")
    }

    func testContentQueryFlowsIntoScanOptions() {
        let command = AIScanCommand(
            target: .recent(limit: 100), mode: .conservative, contentQuery: "beach"
        )
        XCTAssertEqual(command.toScanRequest().options.contentQuery, "beach")
    }
}
