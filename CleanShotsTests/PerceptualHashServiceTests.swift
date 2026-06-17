import XCTest
@testable import CleanShots

final class PerceptualHashServiceTests: XCTestCase {
    private let service = PerceptualHashService()

    func testIdenticalImagesHaveZeroDistance() throws {
        // White-left/black-right gives a non-degenerate dHash (left brighter than
        // right at the boundary sets bits).
        let a = TestImages.verticalSplit(.white, .black)
        let b = TestImages.verticalSplit(.white, .black)
        let ha = try XCTUnwrap(service.hash(for: a))
        let hb = try XCTUnwrap(service.hash(for: b))
        XCTAssertEqual(PerceptualHashService.hammingDistance(ha, hb), 0)
        XCTAssertNotEqual(ha, 0, "expected a non-degenerate hash for a patterned image")
    }

    func testDifferentPatternsDiffer() throws {
        // Vertical split has horizontal brightness transitions (bits set); a
        // horizontal split has uniform rows (no horizontal transitions) → differ.
        let vertical = try XCTUnwrap(service.hash(for: TestImages.verticalSplit(.white, .black)))
        let horizontal = try XCTUnwrap(service.hash(for: TestImages.horizontalSplit(.white, .black)))
        XCTAssertGreaterThan(PerceptualHashService.hammingDistance(vertical, horizontal), 0)
    }

    func testHammingDistanceSymmetryAndBounds() {
        let a: UInt64 = 0b1010
        let b: UInt64 = 0b0011
        XCTAssertEqual(PerceptualHashService.hammingDistance(a, b),
                       PerceptualHashService.hammingDistance(b, a))
        XCTAssertEqual(PerceptualHashService.hammingDistance(a, a), 0)
        XCTAssertEqual(PerceptualHashService.hammingDistance(0, UInt64.max), 64)
    }
}
