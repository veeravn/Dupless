import XCTest
@testable import AI_Photo_Optimizer

final class ResumePlannerTests: XCTestCase {
    func testPendingExcludesCachedPreservingOrder() {
        let targets = ["a", "b", "c", "d", "e"]
        let cached: Set<String> = ["b", "d"]
        XCTAssertEqual(ResumePlanner.pendingIdentifiers(targets: targets, cached: cached), ["a", "c", "e"])
    }

    func testNothingCachedMeansAllPending() {
        let targets = ["a", "b", "c"]
        XCTAssertEqual(ResumePlanner.pendingIdentifiers(targets: targets, cached: []), targets)
        XCTAssertFalse(ResumePlanner.isComplete(targets: targets, cached: []))
    }

    func testAllCachedMeansComplete() {
        let targets = ["a", "b", "c"]
        XCTAssertTrue(ResumePlanner.pendingIdentifiers(targets: targets, cached: ["a", "b", "c"]).isEmpty)
        XCTAssertTrue(ResumePlanner.isComplete(targets: targets, cached: ["a", "b", "c"]))
    }

    func testPartialResumeReturnsRemainder() {
        // Simulates interruption: a/b were analyzed before the app was killed.
        let targets = ["a", "b", "c", "d"]
        let analyzedBeforeCrash: Set<String> = ["a", "b"]
        XCTAssertEqual(ResumePlanner.pendingIdentifiers(targets: targets, cached: analyzedBeforeCrash), ["c", "d"])
    }

    func testExtraCachedIdentifiersAreIgnored() {
        // Cache may contain photos from other scopes; only targets matter.
        let targets = ["a", "b"]
        let cached: Set<String> = ["a", "x", "y"]
        XCTAssertEqual(ResumePlanner.pendingIdentifiers(targets: targets, cached: cached), ["b"])
    }
}
