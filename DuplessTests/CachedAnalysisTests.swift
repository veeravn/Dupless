import XCTest
@testable import CleanShots

final class CachedAnalysisTests: XCTestCase {
    func testHashBitPatternRoundTrips() {
        let hashes: [UInt64] = [0, 1, 0xFFFF_FFFF_FFFF_FFFF, 0x8000_0000_0000_0000, 0x1234_5678_9ABC_DEF0]
        for hash in hashes {
            let cached = CachedAnalysis(id: "x", pixelCount: 10, blockingKey: "k", hash: hash, featurePrintData: nil)
            XCTAssertEqual(cached.hash, hash, "round trip failed for \(hash)")
        }
    }

    func testToAnalyzedPhotoCarriesFields() {
        let cached = CachedAnalysis(id: "photo1", pixelCount: 4242, blockingKey: "block-x", hash: 0xABCD, featurePrintData: nil)
        let analyzed = cached.toAnalyzedPhoto()
        XCTAssertEqual(analyzed.id, "photo1")
        XCTAssertEqual(analyzed.pixelCount, 4242)
        XCTAssertEqual(analyzed.blockingKey, "block-x")
        XCTAssertEqual(analyzed.hash, 0xABCD)
        XCTAssertNil(analyzed.feature)
    }

    func testNilFeatureDataYieldsNilFeature() {
        let cached = CachedAnalysis(id: "x", pixelCount: 1, blockingKey: "k", hash: 1, featurePrintData: nil)
        XCTAssertNil(cached.toAnalyzedPhoto().feature)
    }

    func testRecordConversionRoundTrips() {
        let cached = CachedAnalysis(id: "id-9", pixelCount: 99, blockingKey: "bk", hash: 0xDEAD_BEEF, featurePrintData: Data([1, 2, 3]))
        let record = ImageFeatureRecord(cached: cached)
        let back = record.cachedAnalysis
        XCTAssertEqual(back, cached)
    }
}
