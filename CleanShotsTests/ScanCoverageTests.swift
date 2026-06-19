import XCTest
@testable import CleanShots

final class ScanCoverageTests: XCTestCase {
    private func analysis(_ id: String) -> CachedAnalysis {
        CachedAnalysis(id: id, pixelCount: 1, blockingKey: "k", hash: 0, featurePrintData: nil)
    }

    func testCountsUnanalyzedTargets() {
        // 3 targets, only 2 analyzed (e.g. "b" is iCloud-only) → 1 skipped.
        let skipped = ScanCoverage.skippedCount(targets: ["a", "b", "c"], analyzed: [analysis("a"), analysis("c")])
        XCTAssertEqual(skipped, 1)
    }

    func testZeroWhenFullyCovered() {
        XCTAssertEqual(ScanCoverage.skippedCount(targets: ["a", "b"], analyzed: [analysis("a"), analysis("b")]), 0)
    }

    func testAllSkippedWhenNoneAnalyzed() {
        XCTAssertEqual(ScanCoverage.skippedCount(targets: ["a", "b", "c"], analyzed: []), 3)
    }

    func testIgnoresExtraAnalysesNotInTargets() {
        // An analysis not in the target set shouldn't make coverage look better.
        let skipped = ScanCoverage.skippedCount(targets: ["a", "b"], analyzed: [analysis("a"), analysis("z")])
        XCTAssertEqual(skipped, 1)
    }

    func testEmptyTargets() {
        XCTAssertEqual(ScanCoverage.skippedCount(targets: [], analyzed: []), 0)
    }
}
