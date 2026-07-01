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

    // MARK: - Session-relaxed grouping (Aggressive only)

    // Two hashes used throughout:
    // - poseHash: 20 bits → 0.3125, WITHIN the Hamming prefilter (22). Groups via
    //   the strict path at balanced (≤0.55) / aggressive (≤0.80), not conservative.
    // - farHash: 30 bits → 0.469, PAST the prefilter, so the strict path can never
    //   group it. Only the relaxed same-session pass can — and that pass now runs
    //   at AGGRESSIVE only. So farHash isolates relaxed-pass behavior.
    private let keeperHash: UInt64 = 0
    private let poseHash: UInt64 = 0x0000_0000_000F_FFFF // 20 bits → within prefilter
    private let farHash: UInt64 = 0x0000_0000_3FFF_FFFF  // 30 bits → past prefilter
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

    func testRelaxedPassGroupsSameSessionAtAggressive() {
        // farHash is past the prefilter, so only the relaxed pass can group it —
        // and only at aggressive.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60)),
        ]
        let groups = grouper.group(photos, sensitivity: .aggressive)
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(Set(groups[0].memberIdentifiers), ["a", "b"])
    }

    func testRelaxedPassOffByDefault() {
        // Same session, same backdrop, different moment (past the prefilter). The
        // default must NOT merge these — testers wanted distinct moments kept apart.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60)),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .conservative).isEmpty)
        XCTAssertTrue(grouper.group(photos, sensitivity: .balanced).isEmpty,
                      "Same-backdrop different-moment shots must not group by default")
    }

    func testFarApartInTimeStaysSeparate() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(7200)),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .aggressive).isEmpty)
    }

    func testMissingDatesStaySeparate() {
        // No dates → no session → the relaxed pass can't fire, and farHash is past
        // the strict prefilter, so nothing groups even at aggressive.
        let photos = [
            photo("a", hash: keeperHash),
            photo("b", hash: farHash),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .aggressive).isEmpty)
    }

    func testSameTimeButDistantLocationStaysSeparate() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, lat: 40.7128, lon: -74.0060),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60),
                  lat: 34.0522, lon: -118.2437),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .aggressive).isEmpty)
    }

    func testSameSessionWithCloseLocationGroups() {
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, lat: 40.7128, lon: -74.0060),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60),
                  lat: 40.7129, lon: -74.0060),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .aggressive).count, 1)
    }

    // MARK: - Composition guard (different group sizes shouldn't merge)

    // TestFlight report: at a party with the same backdrop, "the couple" and
    // "the whole family" were grouped together. Different group sizes are
    // distinct keepsakes, not duplicates — even visually similar and same-session.
    func testDifferentFaceCountsStaySeparateEvenWhenVisuallySimilar() {
        // Balanced would group these via the strict path (hamming 20 ≤ prefilter,
        // 0.3125 ≤ 0.55); the equal-count rule in samePeople must override that.
        let photos = [
            photo("couple", hash: keeperHash, date: sessionStart, faces: 2),
            photo("family", hash: poseHash, date: sessionStart.addingTimeInterval(60), faces: 4),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .balanced).isEmpty,
                      "Different group sizes at the same backdrop must not group")
    }

    func testPeopleWithoutPrintsStaySeparate() {
        // People present (faces > 0) but no face prints — an iCloud render that
        // couldn't be produced, or the Simulator's device-only model. samePeople
        // fails SAFE: don't merge on head count alone, even in near-identical
        // frames. This is what keeps 4 men from 4 women once prints go missing.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, faces: 2),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60), faces: 2),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .balanced).isEmpty)
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

    // MARK: - Color guard (relaxed pass, Aggressive)

    // TestFlight report: bust-level close-ups with *different outfits* grouped
    // together because the background looked the same. On the relaxed pass
    // (aggressive; farHash to bypass the strict path) a same-backdrop pair whose
    // color distribution diverges must not merge.
    func testDifferentColorsStaySeparateSameSession() {
        let photos = [
            photo("redTop", hash: keeperHash, date: sessionStart, color: colorSig(bin: 0)),
            photo("blueTop", hash: farHash, date: sessionStart.addingTimeInterval(60),
                  color: colorSig(bin: 63)),
        ]
        XCTAssertTrue(grouper.group(photos, sensitivity: .aggressive).isEmpty,
                      "Same backdrop but different subject color must not group")
    }

    func testSimilarColorsStillGroup() {
        // Same session, same color distribution → the relaxed pass collapses them.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, color: colorSig(bin: 10)),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60),
                  color: colorSig(bin: 10)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .aggressive).count, 1)
    }

    func testMissingColorSignatureFallsBackToVisualGrouping() {
        // One photo has no color signature (older cache) → the color gate is
        // skipped and the relaxed pass groups on the visual signals.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart, color: colorSig(bin: 0)),
            photo("b", hash: farHash, date: sessionStart.addingTimeInterval(60)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .aggressive).count, 1)
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

    func testFacelessPhotosGroupOnVisualSignals() {
        // No faces at all (landscapes) → no identity to check, so near-identical
        // frames still collapse via the strict path at balanced.
        let photos = [
            photo("a", hash: keeperHash, date: sessionStart),
            photo("b", hash: poseHash, date: sessionStart.addingTimeInterval(60)),
        ]
        XCTAssertEqual(grouper.group(photos, sensitivity: .balanced).count, 1)
    }
}

/// Guards the migration-safety of additive `PhotoFlags` fields: records written by
/// an older pipeline (whose stored JSON lacks newer keys) must still decode, with
/// the new fields taking their defaults. Without the custom `init(from:)` Swift
/// throws `keyNotFound` for non-optional defaulted fields, which broke reading the
/// cache across versions and silently disabled face-identity matching.
final class PhotoFlagsCodableMigrationTests: XCTestCase {
    func testDecodesOldRecordMissingNewerKeys() throws {
        // JSON as an older build would have stored it — no faceprints/analysisVersion.
        let oldJSON = """
        {"isFavorite":true,"isEdited":false,"isLivePhoto":false,
         "isHidden":false,"isShared":false,"faceCount":3,"personDetected":true}
        """.data(using: .utf8)!
        let flags = try JSONDecoder().decode(PhotoFlags.self, from: oldJSON)
        XCTAssertEqual(flags.faceCount, 3)
        XCTAssertTrue(flags.isFavorite)
        XCTAssertTrue(flags.personDetected)
        XCTAssertEqual(flags.faceprints, [], "missing faceprints must default to empty")
        XCTAssertEqual(flags.analysisVersion, 0, "missing version must default to 0 → re-analyze")
    }

    func testRoundTripsCurrentRecord() throws {
        let original = PhotoFlags(faceCount: 2, personDetected: true,
                                  faceprints: [Data([1, 2, 3])], analysisVersion: 1)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PhotoFlags.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
