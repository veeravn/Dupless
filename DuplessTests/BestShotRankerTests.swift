import XCTest
@testable import CleanShots

final class BestShotRankerTests: XCTestCase {
    private let ranker = BestShotRanker()

    private func photo(
        _ id: String,
        sharp: Double = 0.5, exposure: Double = 0.5, contrast: Double = 0.5, blur: Double = 0.0,
        pixels: Int = 1000,
        favorite: Bool = false, edited: Bool = false, live: Bool = false, person: Bool = false,
        faces: Int = 0, hidden: Bool = false, shared: Bool = false
    ) -> RankablePhoto {
        RankablePhoto(
            id: id,
            pixelCount: pixels,
            quality: QualityScores(sharpness: sharp, exposure: exposure, contrast: contrast, motionBlur: blur),
            flags: PhotoFlags(isFavorite: favorite, isEdited: edited, isLivePhoto: live,
                              isHidden: hidden, isShared: shared, faceCount: faces, personDetected: person)
        )
    }

    func testSharperPhotoIsKeeper() {
        let result = ranker.rank([photo("dull", sharp: 0.2), photo("crisp", sharp: 0.95)])
        XCTAssertEqual(result.keeperIdentifier, "crisp")
        XCTAssertEqual(result.suggestedRemovalIdentifiers, ["dull"])
    }

    func testHigherResolutionWinsWhenQualityEqual() {
        let result = ranker.rank([photo("small", pixels: 1000), photo("big", pixels: 9000)])
        XCTAssertEqual(result.keeperIdentifier, "big")
    }

    func testEditedVersionIsPreferred() {
        // Edited raises the protection-value term, so the edited version wins.
        let result = ranker.rank([photo("original"), photo("edited", edited: true)])
        XCTAssertEqual(result.keeperIdentifier, "edited")
    }

    func testLivePhotoWinsPureTieBreak() {
        // Live-photo flag isn't part of the score, so scores are equal here and
        // the Live Photo tie-breaker decides the keeper.
        let result = ranker.rank([photo("still"), photo("live", live: true)])
        XCTAssertEqual(result.keeperIdentifier, "live")
        XCTAssertEqual(result.suggestedRemovalIdentifiers, ["still"])
    }

    func testProtectedPhotoNeverSuggestedForRemoval() {
        // The favorite is low quality but must not be suggested for removal.
        let result = ranker.rank([
            photo("keeper", sharp: 0.9, pixels: 9000),
            photo("fav", sharp: 0.1, pixels: 1000, favorite: true),
            photo("dupe", sharp: 0.2, pixels: 1000),
        ])
        XCTAssertEqual(result.keeperIdentifier, "keeper")
        XCTAssertTrue(result.protectedIdentifiers.contains("fav"))
        XCTAssertFalse(result.suggestedRemovalIdentifiers.contains("fav"))
        XCTAssertEqual(result.suggestedRemovalIdentifiers, ["dupe"])
    }

    func testKeeperNeverInRemovals() {
        let result = ranker.rank([photo("a", sharp: 0.9), photo("b", sharp: 0.5), photo("c", sharp: 0.4)])
        let keeper = try? XCTUnwrap(result.keeperIdentifier)
        XCTAssertFalse(result.suggestedRemovalIdentifiers.contains(keeper ?? ""))
    }

    func testAllNonKeeperProtectedYieldsNoRemovals() {
        let result = ranker.rank([
            photo("keeper", sharp: 0.9),
            photo("p1", sharp: 0.3, favorite: true),
            photo("p2", sharp: 0.3, person: true),
        ])
        XCTAssertEqual(result.keeperIdentifier, "keeper")
        XCTAssertTrue(result.suggestedRemovalIdentifiers.isEmpty)
        XCTAssertEqual(Set(result.protectedIdentifiers), ["p1", "p2"])
    }

    func testResolutionBadges() {
        let result = ranker.rank([photo("big", pixels: 8000), photo("small", pixels: 2000)])
        XCTAssertTrue(result.badges["big"]?.contains(.highestResolution) ?? false)
        XCTAssertTrue(result.badges["small"]?.contains(.lowerResolution) ?? false)
    }

    func testBlurryBadge() {
        let result = ranker.rank([photo("crisp", sharp: 0.9), photo("blurred", sharp: 0.9, blur: 0.8)])
        XCTAssertTrue(result.badges["blurred"]?.contains(.blurry) ?? false)
        XCTAssertFalse(result.badges["crisp"]?.contains(.blurry) ?? true)
    }

    func testProtectedBadgeForFavorite() {
        let result = ranker.rank([photo("a", sharp: 0.9), photo("fav", favorite: true)])
        XCTAssertTrue(result.badges["fav"]?.contains(.protected) ?? false)
        XCTAssertTrue(result.badges["fav"]?.contains(.favorite) ?? false)
    }

    func testEmptyInput() {
        let result = ranker.rank([])
        XCTAssertNil(result.keeperIdentifier)
        XCTAssertTrue(result.suggestedRemovalIdentifiers.isEmpty)
    }

    func testSinglePhotoHasNoRemovals() {
        let result = ranker.rank([photo("only")])
        XCTAssertEqual(result.keeperIdentifier, "only")
        XCTAssertTrue(result.suggestedRemovalIdentifiers.isEmpty)
    }

    func testScoreWeightingFavorsSharpness() {
        // Sharpness has the largest weight (0.30); a big sharpness lead should win
        // even against a resolution disadvantage.
        let result = ranker.rank([
            photo("sharp_lowres", sharp: 1.0, pixels: 1000),
            photo("dull_hires", sharp: 0.1, pixels: 9000),
        ])
        XCTAssertEqual(result.keeperIdentifier, "sharp_lowres")
    }
}
