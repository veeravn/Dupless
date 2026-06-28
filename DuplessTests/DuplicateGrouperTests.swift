import XCTest
@testable import Dupless

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

    // MARK: - Session-relaxed grouping (same backdrop, different poses)

    // 20 bits apart → 0.3125: above the conservative strict threshold (0.30) but
    // within its relaxed threshold (0.50). So it groups under conservative *only*
    // when the two are in the same shooting session.
    private let keeperHash: UInt64 = 0
    private let poseHash: UInt64 = 0x0000_0000_000F_FFFF
    private let sessionStart = Date(timeIntervalSince1970: 1_000_000)

    private func photo(_ id: String, hash: UInt64, date: Date? = nil,
                       lat: Double? = nil, lon: Double? = nil, faces: Int = 0,
                       color: Data? = nil) -> AnalyzedPhoto {
        AnalyzedPhoto(id: id, pixelCount: 1000, blockingKey: "block", hash: hash,
                      feature: nil, captureDate: date, latitude: lat, longitude: lon,
                      faceCount: faces, colorSignature: color)
    }

    /// A 64-bin color signature with all weight in a single bin — two different
    /// bins give disjoint histograms (intersection 0), the same bin gives identical
    /// ones (intersection 1.0).
    private func colorSig(bin: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: 64)
        bytes[bin] = 255
        return Data(bytes)
    }

    func testSameSessionGroupsDifferentPoses() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60)),
        ]
        let groups = grouper.group(photos, sensitivity: .conservative)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].memberIdentifiers), ["a", "b"])
    }

    func testFarApartInTimeStaysSeparate() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(7200)),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty)
    }

    func testMissingDatesUseStrictThresholdOnly() {
        let photos = [
            photo("a", hash: keeperHash),
            photo("b", hash: poseHash),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty)
    }

    func testSameTimeButDistantLocationStaysSeparate() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, lat: 40.7128, lon: -74.0060),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60),
                  lat: 34.0522, lon: -118.2437),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty)
    }

    func testSameSessionWithCloseLocationGroups() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, lat: 40.7128, lon: -74.0060),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60),
                  lat: 40.7129, lon: -74.0060),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }

    // MARK: - Composition guard (different group sizes shouldn't merge)

    // TestFlight report: at a party with the same backdrop, "the couple" and
    // "the whole family" were grouped together. Different group sizes are
    // distinct keepsakes, not duplicates — even visually similar and same-session.
    func testDifferentFaceCountsStaySeparateEvenWhenVisuallySimilar() {
        // Balanced would group these on BOTH the strict and session-relaxed paths
        // (hamming 20 ≤ prefilter, 0.3125 ≤ thresholds); the composition guard
        // must override that.
        let photos = [
            photo("couple", hash: keeperHash, date: sessionStart, faces: 2),
            photo("family", hash: poseHash, date: sessionStart.addingTimeInterval(60), faces: 4),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .balanced).isEmpty,
                      "Different group sizes at the same backdrop must not group")
    }

    func testSameFaceCountStillGroupsAcrossPoses() {
        // Same two people, different poses in one session → still collapses.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, faces: 2),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60), faces: 2),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }

    func testCoupleVsCouplePlusFriendStaySeparate() {
        // "The couple" (2) vs "the couple + a friend" (3) at one backdrop is a
        // different keepsake, not a duplicate — even visually near-identical and
        // same-session. The equal-count rule (not ±1) must keep them apart on BOTH
        // paths. Balanced would otherwise group them (0.3125 ≤ strict 0.55).
        let photos = [
            photo("couple", hash: keeperHash, date: sessionStart, faces: 2),
            photo("plusFriend", hash: poseHash, date: sessionStart.addingTimeInterval(60), faces: 3),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .balanced).isEmpty,
                      "Adding a person makes it a distinct photo — must not group")
    }

    // 30 bits apart → exceeds the Hamming prefilter (22), so the strict path
    // rejects the pair outright. A pose change can shift the perceptual hash this
    // far, so a same-session pair must bypass the prefilter and still group via
    // the relaxed feature check (30/64 ≈ 0.47 ≤ conservative relaxed 0.50).
    private let farHash: UInt64 = 0x0000_0000_3FFF_FFFF // 30 bits set

    func testSameSessionGroupsPastHammingPrefilter() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }

    func testPastPrefilterStaysSeparateWhenNotSameSession() {
        let photos = [
            photo("a", hash: keeperHash),
            photo("b", hash: farHash), // no dates → strict path only, prefilter rejects
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .aggressive).isEmpty)
    }

    // MARK: - Color guard (same backdrop, different subject color)

    // TestFlight report: bust-level close-ups with *different outfits* grouped
    // together because the background looked the same. The relaxed same-session
    // path must not merge a same-backdrop pair whose color distribution diverges.
    func testDifferentColorsStaySeparateSameSession() {
        // Same session, poseHash (0.3125 ≤ conservative relaxed 0.50) so the visual
        // signals alone *would* group — but disjoint color histograms block it.
        let photos = [
            photo("redTop", hash: keeperHash, date: sessionStart, color: colorSig(bin: 0)),
            photo("blueTop", hash: poseHash, date: sessionStart.addingTimeInterval(60),
                  color: colorSig(bin: 63)),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty,
                      "Same backdrop but different subject color must not group")
    }

    func testSimilarColorsStillGroup() {
        // Same session, same color distribution → the relaxed path still collapses
        // the pose change to one keeper.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, color: colorSig(bin: 10)),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60),
                  color: colorSig(bin: 10)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }

    func testMissingColorSignatureFallsBackToVisualGrouping() {
        // One photo has no color signature (older cache) → the color gate is
        // skipped and the pair groups on the visual signals exactly as before.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, color: colorSig(bin: 0)),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }

    func testDifferentColorsIrrelevantOnStrictPath() {
        // The color gate only guards the relaxed same-session path. A true visual
        // duplicate (identical hash, within the strict threshold) still groups even
        // with divergent color — protects flash/no-flash pairs of the same scene.
        let photos = [
            photo("a", hash: keeperHash, color: colorSig(bin: 0)),
            photo("b", hash: keeperHash, color: colorSig(bin: 63)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }

    // MARK: - People-set matching (different family units, same backdrop)

    // TestFlight report: the SAME seated couple was photographed with different
    // family members around them at one venue — same head count, same dominant
    // colors — and all the shots merged. The faces are the only thing that
    // differs. `faceprintsMatch` is the pure set-matching core; the feature-print
    // model is device-only, so the per-face distance is injected here (0 = same
    // person, 1 = different) exactly as the hash-fallback tests stand in for the
    // device feature print elsewhere.
    private func face(_ tag: UInt8) -> Data { Data([tag]) }
    private func exactMatch(_ a: Data, _ b: Data) -> Float { a == b ? 0 : 1 }
    private let faceThreshold: Float = 0.5

    func testSamePeopleMatch() {
        XCTAssertTrue(DuplicateGrouper.faceprintsMatch(
            [face(1), face(2)], [face(1), face(2)],
            threshold: faceThreshold, distance: exactMatch))
    }

    func testSamePeopleMatchIsOrderInvariant() {
        XCTAssertTrue(DuplicateGrouper.faceprintsMatch(
            [face(1), face(2)], [face(2), face(1)],
            threshold: faceThreshold, distance: exactMatch))
    }

    func testDifferentPeopleSameCountDoNotMatch() {
        // The party case: shared person 1, but 2 vs 3 → an unmatched face on each
        // side ⇒ different grouping.
        XCTAssertFalse(DuplicateGrouper.faceprintsMatch(
            [face(1), face(2)], [face(1), face(3)],
            threshold: faceThreshold, distance: exactMatch))
    }

    func testSharedCoupleDifferentGuestsDoNotMatch() {
        // Seated couple (1,2) identical across both; the third person differs.
        XCTAssertFalse(DuplicateGrouper.faceprintsMatch(
            [face(1), face(2), face(3)], [face(1), face(2), face(4)],
            threshold: faceThreshold, distance: exactMatch))
    }

    func testSubsetOfPeopleStillMatches() {
        // Smaller side fully present in the larger (a face momentarily missed, or
        // one extra person) — the count guard governs that ±1, not this check.
        XCTAssertTrue(DuplicateGrouper.faceprintsMatch(
            [face(1)], [face(1), face(2)],
            threshold: faceThreshold, distance: exactMatch))
    }

    func testNearButDistinctFacesBlockedByThreshold() {
        // Same person across a pose change sits just under the threshold and
        // matches; a clearly different face sits above it and blocks.
        let near: (Data, Data) -> Float = { a, b in a == b ? 0 : (a == self.face(1) && b == self.face(9) ? 0.4 : 1) }
        XCTAssertTrue(DuplicateGrouper.faceprintsMatch(
            [face(1)], [face(9)], threshold: faceThreshold, distance: near),
            "0.4 ≤ 0.5 → same person")
        XCTAssertFalse(DuplicateGrouper.faceprintsMatch(
            [face(1)], [face(2)], threshold: faceThreshold, distance: near),
            "1.0 > 0.5 → different person")
    }

    func testMissingFaceprintsFallBackToCountGuard() {
        // No prints on either side (Simulator / older cache) → grouping is
        // unchanged: same-session different poses still collapse.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .conservative).count, 1)
    }
}
