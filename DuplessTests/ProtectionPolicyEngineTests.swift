import XCTest
@testable import Dupless

final class ProtectionPolicyEngineTests: XCTestCase {
    private let engine = ProtectionPolicyEngine()

    func testUnflaggedPhotoIsNotProtected() {
        XCTAssertFalse(engine.isProtected(.none))
        XCTAssertTrue(engine.protectionReasons(for: .none).isEmpty)
    }

    func testEachFlagProducesItsReason() {
        XCTAssertEqual(engine.protectionReasons(for: PhotoFlags(isFavorite: true)), [.favorite])
        XCTAssertEqual(engine.protectionReasons(for: PhotoFlags(isEdited: true)), [.edited])
        XCTAssertEqual(engine.protectionReasons(for: PhotoFlags(isLivePhoto: true)), [.livePhoto])
        XCTAssertEqual(engine.protectionReasons(for: PhotoFlags(isHidden: true)), [.hidden])
        XCTAssertEqual(engine.protectionReasons(for: PhotoFlags(isShared: true)), [.shared])
        XCTAssertEqual(engine.protectionReasons(for: PhotoFlags(personDetected: true)), [.hasPeople])
    }

    func testMultipleReasons() {
        let flags = PhotoFlags(isFavorite: true, isEdited: true, personDetected: true)
        XCTAssertEqual(Set(engine.protectionReasons(for: flags)), [.favorite, .edited, .hasPeople])
    }

    func testDisabledProtectionIsIgnored() {
        var policy = ProtectionPolicy.default
        policy.protectPeople = false
        let engine = ProtectionPolicyEngine(policy: policy)
        XCTAssertFalse(engine.isProtected(PhotoFlags(personDetected: true)))
        // But a favorite is still protected.
        XCTAssertTrue(engine.isProtected(PhotoFlags(isFavorite: true)))
    }
}
