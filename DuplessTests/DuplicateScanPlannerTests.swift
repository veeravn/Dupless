import XCTest
@testable import CleanShots

final class DuplicateScanPlannerTests: XCTestCase {
    private func analysis(_ id: String, hash: UInt64, pixels: Int, sharp: Double) -> CachedAnalysis {
        CachedAnalysis(
            id: id, pixelCount: pixels, blockingKey: "k", hash: hash, featurePrintData: nil,
            quality: QualityScores(sharpness: sharp, exposure: 0.5, contrast: 0.5, motionBlur: 0.1),
            flags: .none
        )
    }

    /// The persisted keeper must be the MVP 2 *ranked* best shot, not the
    /// grouper's highest-resolution placeholder.
    func testKeeperIsRankedBestShotNotHighestResolution() {
        // "big" is highest resolution but soft; "sharp" is lower-res but crisp.
        let results = DuplicateScanPlanner(sensitivity: .balanced).plan([
            analysis("big", hash: 0, pixels: 9000, sharp: 0.2),
            analysis("sharp", hash: 0, pixels: 1000, sharp: 0.95),
        ])
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results[0].keeperIdentifier, "sharp")
        XCTAssertEqual(Set(results[0].memberIdentifiers), ["big", "sharp"])
        XCTAssertGreaterThan(results[0].confidence, 0.5)
    }

    func testDistinctPhotosAreNotGrouped() {
        let results = DuplicateScanPlanner(sensitivity: .balanced).plan([
            analysis("a", hash: 0, pixels: 1000, sharp: 0.5),
            analysis("b", hash: .max, pixels: 1000, sharp: 0.5), // far hash → own group (dropped)
        ])
        XCTAssertTrue(results.isEmpty, "Visually distinct singletons aren't duplicate groups.")
    }

    func testEmptyInput() {
        XCTAssertTrue(DuplicateScanPlanner(sensitivity: .balanced).plan([]).isEmpty)
    }
}
