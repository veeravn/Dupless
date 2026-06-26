import XCTest
@testable import CleanShots

final class ScanParserTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func resolver() -> DatePhraseResolver {
        DatePhraseResolver(calendar: cal, now: cal.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 15))!)
    }

    private func parser() -> TemplateScanParser { TemplateScanParser(resolver: resolver()) }

    // MARK: - Mode

    func testParsesConservativeMode() async {
        let result = await parser().parse("find similar photos but be conservative", defaultMode: .balanced)
        XCTAssertEqual(result.command.mode, .conservative)
        XCTAssertTrue(result.understood)
    }

    func testParsesAggressiveSynonyms() async {
        let result = await parser().parse("do a thorough cleanup", defaultMode: .balanced)
        XCTAssertEqual(result.command.mode, .aggressive)
    }

    func testFallsBackToDefaultModeWhenUnspecified() async {
        let result = await parser().parse("clean up my photos from last month", defaultMode: .aggressive)
        XCTAssertEqual(result.command.mode, .aggressive)
    }

    // MARK: - Date scope

    func testParsesLastWeekendIntoResolvedDateRange() async {
        let result = await parser().parse("compare photos from last weekend", defaultMode: .balanced)
        let expected = resolver().resolve(.lastWeekend)
        XCTAssertEqual(result.command.target, .dateRange(start: expected.start, end: expected.end))
        XCTAssertTrue(result.understood)
    }

    func testNoDatePhraseDefaultsToRecent() async {
        let result = await parser().parse("be conservative", defaultMode: .balanced)
        XCTAssertEqual(result.command.target, .recent(limit: 300))
    }

    // MARK: - Screenshots

    func testExcludesScreenshotsOnRequest() async {
        let result = await parser().parse("scan last week without screenshots", defaultMode: .balanced)
        XCTAssertFalse(result.command.includeScreenshots)
    }

    func testIncludesScreenshotsByDefault() async {
        let result = await parser().parse("scan last week", defaultMode: .balanced)
        XCTAssertTrue(result.command.includeScreenshots)
    }

    // MARK: - Understood flag & safety

    func testGibberishIsNotUnderstoodAndUsesSafeDefaults() async {
        let result = await parser().parse("hello there", defaultMode: .balanced)
        XCTAssertFalse(result.understood)
        XCTAssertEqual(result.command.target, .recent(limit: 300))
        XCTAssertEqual(result.command.mode, .balanced)
    }

    func testAlwaysRequiresReview() async {
        let result = await parser().parse("aggressively delete everything from last year", defaultMode: .balanced)
        XCTAssertTrue(result.command.requireReview, "Parser must never bypass manual review.")
    }

    // MARK: - Summary

    func testSummaryDescribesResolvedSettings() async {
        let result = await parser().parse("conservative scan of last weekend", defaultMode: .balanced)
        XCTAssertTrue(result.summary.contains("Conservative"), result.summary)
        XCTAssertTrue(result.summary.contains("last weekend"), result.summary)
        XCTAssertTrue(result.summary.contains("including screenshots"), result.summary)
    }
}
