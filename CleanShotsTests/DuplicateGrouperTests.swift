import XCTest
@testable import CleanShots

final class DuplicateGrouperTests: XCTestCase {
    private let grouper = DuplicateGrouper()

    func testIdenticalHashesFormOneGroup() {
        let photos = [
            AnalyzedPhoto.make(id: "a", hash: 0xFFFF_0000_FFFF_0000),
            AnalyzedPhoto.make(id: "b", hash: 0xFFFF_0000_FFFF_0000),
            AnalyzedPhoto.make(id: "c", hash: 0xFFFF_0000_FFFF_0000),
        ]
        let groups = grouper.group(photos, sensitivity: .balanced)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].memberIdentifiers), ["a", "b", "c"])
    }

    func testDissimilarPhotosDoNotGroup() {
        let photos = [
            AnalyzedPhoto.make(id: "a", hash: 0x0000_0000_0000_0000),
            AnalyzedPhoto.make(id: "b", hash: 0xFFFF_FFFF_FFFF_FFFF), // 64-bit apart
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty)
    }

    func testDifferentBlockingKeysNeverCompared() {
        let photos = [
            AnalyzedPhoto.make(id: "a", hash: 0xABCD, blockingKey: "day1"),
            AnalyzedPhoto.make(id: "b", hash: 0xABCD, blockingKey: "day2"),
        ]
        // Identical hashes, but different blocks → not grouped.
        XCTAssertTrue(grouper.group(photos, sensitivity: .aggressive).isEmpty)
    }

    func testKeeperIsHighestResolution() {
        let photos = [
            AnalyzedPhoto.make(id: "small", hash: 0x00FF, pixelCount: 1000),
            AnalyzedPhoto.make(id: "big", hash: 0x00FF, pixelCount: 9000),
            AnalyzedPhoto.make(id: "mid", hash: 0x00FF, pixelCount: 4000),
        ]
        let groups = grouper.group(photos, sensitivity: .balanced)
        XCTAssertEqual(groups.first?.keeperIdentifier, "big")
    }

    func testSingletonsAreExcluded() {
        let photos = [
            AnalyzedPhoto.make(id: "lonely", hash: 0x1111, blockingKey: "x"),
            AnalyzedPhoto.make(id: "pair1", hash: 0x2222, blockingKey: "y"),
            AnalyzedPhoto.make(id: "pair2", hash: 0x2222, blockingKey: "y"),
        ]
        let groups = grouper.group(photos, sensitivity: .balanced)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].memberIdentifiers), ["pair1", "pair2"])
    }

    func testConfidenceWithinBounds() {
        let photos = [
            AnalyzedPhoto.make(id: "a", hash: 0xFF00),
            AnalyzedPhoto.make(id: "b", hash: 0xFF00),
        ]
        let confidence = grouper.group(photos, sensitivity: .balanced).first?.confidence ?? 0
        XCTAssertGreaterThanOrEqual(confidence, 0.5)
        XCTAssertLessThanOrEqual(confidence, 0.99)
    }

    func testEmptyInputYieldsNoGroups() {
        XCTAssertTrue(grouper.group([], sensitivity: .balanced).isEmpty)
    }

    func testConservativeStricterThanAggressive() {
        // 20 bits apart → fallback distance 20/64 ≈ 0.3125: passes the Hamming
        // prefilter (22) but is above the conservative threshold (0.30) and below
        // aggressive (0.80). So it groups at aggressive, not at conservative.
        let photos = [
            AnalyzedPhoto.make(id: "a", hash: 0x0000_0000_0000_0000),
            AnalyzedPhoto.make(id: "b", hash: 0x0000_0000_000F_FFFF), // 20 bits set
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty)
        XCTAssertEqual(grouper.group(photos, sensitivity: .aggressive).count, 1)
    }
}
