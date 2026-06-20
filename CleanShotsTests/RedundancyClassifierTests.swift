import XCTest
@testable import CleanShots

final class RedundancyClassifierTests: XCTestCase {
    // Feature-print-free photos so the classifier uses the Hamming fallback:
    // distance = differingBits / 64. The default redundantDistance of 0.22 maps
    // to ~14 bits.
    private func photo(_ id: String, hash: UInt64) -> AnalyzedPhoto {
        AnalyzedPhoto(id: id, pixelCount: 1000, blockingKey: "k", hash: hash, feature: nil)
    }

    func testNearIdenticalFramesAreRedundantButDistinctPosesAreNot() {
        let keeper = photo("keeper", hash: 0)
        let nearFrame = photo("near", hash: 0b1111)        // 4 bits  -> 0.0625
        let differentPose = photo("pose", hash: 0xFFFFFFFF) // 32 bits -> 0.5

        let result = RedundancyClassifier().redundantIdentifiers(
            members: [keeper, nearFrame, differentPose], keeperID: "keeper")

        XCTAssertEqual(result, ["near"])
    }

    func testKeeperIsNeverRedundant() {
        let keeper = photo("keeper", hash: 0)
        let near = photo("near", hash: 0b11)
        let result = RedundancyClassifier().redundantIdentifiers(
            members: [keeper, near], keeperID: "keeper")
        XCTAssertFalse(result.contains("keeper"))
    }

    func testNoKeeperYieldsEmpty() {
        let lonely = photo("a", hash: 0)
        XCTAssertTrue(
            RedundancyClassifier().redundantIdentifiers(members: [lonely], keeperID: nil).isEmpty)
    }

    func testThresholdIsRespected() {
        var classifier = RedundancyClassifier()
        classifier.redundantDistance = 0.10 // ~6.4 bits
        let keeper = photo("keeper", hash: 0)
        let inside = photo("inside", hash: 0b1111) // 4 bits  0.0625 <= 0.10
        let outside = photo("outside", hash: 0xFF)  // 8 bits  0.125  >  0.10

        let result = classifier.redundantIdentifiers(
            members: [keeper, inside, outside], keeperID: "keeper")

        XCTAssertEqual(result, ["inside"])
    }
}
