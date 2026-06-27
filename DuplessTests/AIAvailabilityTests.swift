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

/// The Pro feature gate is a pure decision (separate from StoreKit) so it can be
/// tested without a purchase. Without Pro every gated feature is locked; with
/// Pro nothing is.
final class ProAccessTests: XCTestCase {
    func testFreeUserHasEveryProFeatureLocked() {
        let access = ProAccess(isPro: false)
        for feature in ProFeature.allCases {
            XCTAssertTrue(access.isLocked(feature), "\(feature) should be locked for a free user")
        }
    }

    func testProUserHasNothingLocked() {
        let access = ProAccess(isPro: true)
        for feature in ProFeature.allCases {
            XCTAssertFalse(access.isLocked(feature), "\(feature) should be unlocked for a Pro user")
        }
    }

    func testEveryProFeatureHasPresentationMetadata() {
        for feature in ProFeature.allCases {
            XCTAssertFalse(feature.title.isEmpty)
            XCTAssertFalse(feature.systemImage.isEmpty)
            XCTAssertFalse(feature.blurb.isEmpty)
        }
    }
}
