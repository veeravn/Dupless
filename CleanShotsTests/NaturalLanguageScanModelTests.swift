import XCTest
@testable import CleanShots

@MainActor
final class NaturalLanguageScanModelTests: XCTestCase {
    private func model() -> NaturalLanguageScanModel {
        NaturalLanguageScanModel(
            coordinator: NaturalLanguageScanCoordinator(parser: TemplateScanParser()),
            router: .shared
        )
    }

    override func setUp() async throws {
        IntentRouter.shared.route = nil
        AppSettings.defaultSensitivity = .balanced
    }

    func testCanSubmitRequiresNonEmptyQuery() {
        let m = model()
        XCTAssertFalse(m.canSubmit)
        m.query = "   "
        XCTAssertFalse(m.canSubmit)
        m.query = "scan last week"
        XCTAssertTrue(m.canSubmit)
    }

    func testSubmitStagesParsedScanWithoutRouting() async {
        let m = model()
        m.query = "find similar photos from last week, be conservative"
        await m.submit()

        XCTAssertNotNil(m.pending)
        XCTAssertEqual(m.pending?.command.mode, .conservative)
        XCTAssertFalse(m.isParsing)
        // Staging must NOT start a scan on its own.
        XCTAssertNil(IntentRouter.shared.route)
    }

    func testEmptyQueryDoesNotStage() async {
        let m = model()
        m.query = "   "
        await m.submit()
        XCTAssertNil(m.pending)
    }

    func testConfirmRoutesToScanAndClears() async {
        let m = model()
        m.query = "scan last week without screenshots"
        await m.submit()
        let expected = m.pending?.toScanRequest()

        m.confirm()

        XCTAssertEqual(IntentRouter.shared.route, expected.map { AppRoute.scan($0) })
        XCTAssertNil(m.pending)
        XCTAssertEqual(m.query, "")
    }

    func testCancelClearsWithoutRouting() async {
        let m = model()
        m.query = "scan last month"
        await m.submit()
        XCTAssertNotNil(m.pending)

        m.cancel()
        XCTAssertNil(m.pending)
        XCTAssertNil(IntentRouter.shared.route)
    }
}
