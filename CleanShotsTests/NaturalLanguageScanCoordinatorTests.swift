import XCTest
@testable import CleanShots

/// Records the default mode the coordinator passes through, and returns a canned result.
private actor RecordingParser: ScanRequestParsing {
    private(set) var lastDefaultMode: DedupeModeAppEnum?
    private(set) var lastText: String?
    let canned: ParsedScan
    init(canned: ParsedScan) { self.canned = canned }

    func parse(_ text: String, defaultMode: DedupeModeAppEnum) async -> ParsedScan {
        lastText = text
        lastDefaultMode = defaultMode
        return canned
    }
}

final class NaturalLanguageScanCoordinatorTests: XCTestCase {
    private func canned() -> ParsedScan {
        let command = AIScanCommand(target: .recent(limit: 300), mode: .balanced)
        return ParsedScan(command: command, summary: "canned", understood: true)
    }

    func testCoordinatorPassesAppDefaultModeAsBaseline() async {
        AppSettings.defaultSensitivity = .aggressive
        let parser = RecordingParser(canned: canned())
        let coordinator = NaturalLanguageScanCoordinator(parser: parser)

        _ = await coordinator.parse("anything")
        let passed = await parser.lastDefaultMode
        XCTAssertEqual(passed, .aggressive)
    }

    func testCoordinatorForwardsTextAndReturnsParserResult() async {
        AppSettings.defaultSensitivity = .balanced
        let parser = RecordingParser(canned: canned())
        let coordinator = NaturalLanguageScanCoordinator(parser: parser)

        let result = await coordinator.parse("scan last week")
        let forwardedText = await parser.lastText
        XCTAssertEqual(forwardedText, "scan last week")
        XCTAssertEqual(result.summary, "canned")
    }

    func testEndToEndWithTemplateParserResolvesCommand() async {
        AppSettings.defaultSensitivity = .conservative
        let coordinator = NaturalLanguageScanCoordinator(parser: TemplateScanParser())
        let result = await coordinator.parse("be conservative about my recent photos")
        XCTAssertEqual(result.command.mode, .conservative)
        XCTAssertEqual(result.command.target, .recent(limit: 300))
    }
}
