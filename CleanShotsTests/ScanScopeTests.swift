import XCTest
@testable import CleanShots

final class ScanScopeTests: XCTestCase {
    func testSignaturesAreDistinctPerScope() {
        let signatures = Set([
            ScanScope.recent(limit: 100).signature,
            ScanScope.recent(limit: 300).signature,
            ScanScope.album(localIdentifier: "ABC").signature,
            ScanScope.album(localIdentifier: "DEF").signature,
            ScanScope.dateRange(start: Date(timeIntervalSince1970: 0), end: Date(timeIntervalSince1970: 100)).signature,
        ])
        XCTAssertEqual(signatures.count, 5)
    }

    func testSameScopeSameSignature() {
        XCTAssertEqual(ScanScope.recent(limit: 300).signature, ScanScope.recent(limit: 300).signature)
        XCTAssertEqual(ScanScope.album(localIdentifier: "X").signature, ScanScope.album(localIdentifier: "X").signature)
    }

    func testOptionsSignatureReflectsToggles() {
        XCTAssertNotEqual(ScanOptions(includeScreenshots: true, excludeFavorites: true).signature,
                          ScanOptions(includeScreenshots: false, excludeFavorites: true).signature)
        XCTAssertNotEqual(ScanOptions(includeScreenshots: true, excludeFavorites: true).signature,
                          ScanOptions(includeScreenshots: true, excludeFavorites: false).signature)
    }

    func testDisplayNames() {
        XCTAssertEqual(ScanScope.album(localIdentifier: "x").displayName, "Album")
        XCTAssertTrue(ScanScope.recent(limit: 300).displayName.contains("300"))
    }
}
