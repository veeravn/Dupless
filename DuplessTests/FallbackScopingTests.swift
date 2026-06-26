import XCTest
@testable import CleanShots

/// The template parser is the *real* parser on devices without Apple
/// Intelligence, so it must also extract content themes and place names — not
/// just mode/date/screenshots. These verify the deterministic scoping mirrors
/// what the model produces, while staying safe on gibberish.
final class FallbackScopingTests: XCTestCase {
    private func parser() -> TemplateScanParser { TemplateScanParser() }

    // MARK: - scope() classification

    func testKnownVisualSubjectBecomesContent() {
        let (content, location) = TemplateScanParser.scope(in: "find my beach photos")
        XCTAssertEqual(content, "beach")
        XCTAssertNil(location)
    }

    func testNamedPlaceBecomesLocation() {
        let (content, location) = TemplateScanParser.scope(in: "scan my mall of america photos")
        XCTAssertNil(content, "A specific place must not be treated as a visual subject")
        let place = location ?? ""
        XCTAssertTrue(place.contains("mall") && place.contains("america"), place)
    }

    func testTripPhrasingExtractsPlace() {
        let (content, location) = TemplateScanParser.scope(in: "scan photos from my hawaii trip")
        XCTAssertNil(content)
        XCTAssertEqual(location, "hawaii")
    }

    func testNoSubjectLeavesBothNil() {
        let (content, location) = TemplateScanParser.scope(in: "scan my recent photos")
        XCTAssertNil(content)
        XCTAssertNil(location)
    }

    func testUnframedGibberishIsNotScoped() {
        // No scan verb or object noun → don't read a subject at all.
        let (content, location) = TemplateScanParser.scope(in: "hello there")
        XCTAssertNil(content)
        XCTAssertNil(location)
    }

    // MARK: - end-to-end through parse()

    func testPlaceQueryFlowsIntoCommandAndIsUnderstood() async {
        let result = await parser().parse("scan my central park photos", defaultMode: .balanced)
        XCTAssertNil(result.command.contentQuery)
        let place = result.command.locationQuery ?? ""
        XCTAssertTrue(place.contains("central") && place.contains("park"), place)
        XCTAssertTrue(result.understood)
        XCTAssertTrue(result.summary.lowercased().contains("central park"), result.summary)
    }

    func testUndatedPlaceQueryWidensTheRecentWindow() async {
        let result = await parser().parse("scan my disneyland photos", defaultMode: .balanced)
        XCTAssertEqual(result.command.target, .recent(limit: AIScanCommand.placeScopedRecentLimit))
    }

    func testUndatedNonPlaceQueryKeepsDefaultWindow() async {
        let result = await parser().parse("find my beach photos", defaultMode: .balanced)
        XCTAssertEqual(result.command.target, .recent(limit: AIScanCommand.defaultRecentLimit))
    }

    func testContentQueryFlowsIntoCommand() async {
        let result = await parser().parse("clean up my food pics", defaultMode: .balanced)
        XCTAssertEqual(result.command.contentQuery, "food")
        XCTAssertNil(result.command.locationQuery)
        XCTAssertTrue(result.understood)
    }

    func testContentAndDateCombine() async {
        let result = await parser().parse("scan birthday photos from last week", defaultMode: .balanced)
        XCTAssertEqual(result.command.contentQuery, "birthday")
        if case .dateRange = result.command.target {} else {
            XCTFail("Expected a date range for 'last week', got \(result.command.target)")
        }
    }

    func testGibberishStaysNotUnderstood() async {
        let result = await parser().parse("hello there", defaultMode: .balanced)
        XCTAssertFalse(result.understood)
        XCTAssertNil(result.command.contentQuery)
        XCTAssertNil(result.command.locationQuery)
    }
}
