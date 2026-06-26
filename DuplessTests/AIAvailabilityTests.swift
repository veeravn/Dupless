import XCTest
@testable import Dupless

final class AIAvailabilityTests: XCTestCase {
    func testAvailableIsAvailable() {
        XCTAssertTrue(AIAvailability.available.isAvailable)
        XCTAssertEqual(AIAvailability.available.reason, "")
    }

    func testUnavailableCarriesReason() {
        let a = AIAvailability.unavailable(reason: "no model")
        XCTAssertFalse(a.isAvailable)
        XCTAssertEqual(a.reason, "no model")
    }

    func testUnavailableProviderReportsUnavailable() {
        let provider = UnavailableModelProvider(reason: "testing")
        XCTAssertFalse(provider.availability.isAvailable)
        XCTAssertEqual(provider.availability.reason, "testing")
    }
}
