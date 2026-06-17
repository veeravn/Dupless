import Foundation

/// The ranking outcome for one duplicate group.
struct GroupRanking: Sendable, Equatable {
    let keeperIdentifier: String?
    /// Non-keeper, non-protected photos suggested for removal (ranked worst-kept order).
    let suggestedRemovalIdentifiers: [String]
    /// All photos the protection policy keeps (may include the keeper).
    let protectedIdentifiers: [String]
    let finalScores: [String: Double]
    let badges: [String: [QualityBadge]]
}

/// Pure best-shot ranking. Implements the spec's weighted keeper score and
/// tie-breakers, and never suggests removing a protected photo. No PhotoKit.
struct BestShotRanker {
    private let protection: ProtectionPolicyEngine

    init(policy: ProtectionPolicy = .default) {
        self.protection = ProtectionPolicyEngine(policy: policy)
    }

    func rank(_ photos: [RankablePhoto]) -> GroupRanking {
        guard !photos.isEmpty else {
            return GroupRanking(keeperIdentifier: nil, suggestedRemovalIdentifiers: [],
                                protectedIdentifiers: [], finalScores: [:], badges: [:])
        }

        let maxPixels = photos.map(\.pixelCount).max() ?? 1
        let scores = Dictionary(uniqueKeysWithValues: photos.map { ($0.id, finalScore($0, maxPixels: maxPixels)) })
        let badges = computeBadges(photos, maxPixels: maxPixels)

        // Keeper: highest score; ties (similar quality) broken per the spec.
        let ranked = photos.sorted { a, b in
            let ka = sortKey(a, score: scores[a.id] ?? 0)
            let kb = sortKey(b, score: scores[b.id] ?? 0)
            if ka != kb { return ka > kb }
            return a.id < b.id
        }
        let keeper = ranked.first
        let keeperID = keeper?.id

        let protectedIDs = photos.filter { protection.isProtected($0.flags) }.map(\.id)
        let protectedSet = Set(protectedIDs)

        let removals = ranked
            .filter { $0.id != keeperID && !protectedSet.contains($0.id) }
            .map(\.id)

        return GroupRanking(
            keeperIdentifier: keeperID,
            suggestedRemovalIdentifiers: removals,
            protectedIdentifiers: protectedIDs,
            finalScores: scores,
            badges: badges
        )
    }

    // MARK: - Scoring

    func finalScore(_ photo: RankablePhoto, maxPixels: Int) -> Double {
        let resolution = maxPixels > 0 ? Double(photo.pixelCount) / Double(maxPixels) : 0
        let faceValue = photo.flags.personDetected ? min(1.0, 0.5 + Double(photo.flags.faceCount) * 0.1) : 0
        let protectionValue = (photo.flags.isFavorite || photo.flags.isEdited) ? 1.0 : 0.0
        let composition = photo.quality.contrast
        let metadataConfidence = 1.0

        return 0.30 * photo.quality.sharpness
            + 0.20 * photo.quality.exposure
            + 0.15 * resolution
            + 0.10 * faceValue
            + 0.10 * protectionValue
            + 0.10 * composition
            + 0.05 * metadataConfidence
    }

    /// Descending-preference sort key. The rounded score groups "similar quality"
    /// photos so the tie-breakers (edited → resolution → favorite → Live Photo →
    /// people) decide between them.
    private func sortKey(_ photo: RankablePhoto, score: Double) -> (Double, Double, Double, Double, Double, Double) {
        (
            (score * 100).rounded() / 100,
            photo.flags.isEdited ? 1 : 0,
            Double(photo.pixelCount),
            photo.flags.isFavorite ? 1 : 0,
            photo.flags.isLivePhoto ? 1 : 0,
            photo.flags.personDetected ? 1 : 0
        )
    }

    // MARK: - Badges

    private func computeBadges(_ photos: [RankablePhoto], maxPixels: Int) -> [String: [QualityBadge]] {
        let sharpestID = photos.max { $0.quality.sharpness < $1.quality.sharpness }?.id
        let bestExposureID = photos.max { $0.quality.exposure < $1.quality.exposure }?.id

        var result: [String: [QualityBadge]] = [:]
        for photo in photos {
            var badges: [QualityBadge] = []
            if photo.id == sharpestID { badges.append(.sharpest) }
            if photo.id == bestExposureID { badges.append(.bestExposure) }
            if photo.pixelCount == maxPixels {
                badges.append(.highestResolution)
            } else {
                badges.append(.lowerResolution)
            }
            if photo.flags.isEdited { badges.append(.edited) }
            if photo.flags.isFavorite { badges.append(.favorite) }
            if photo.flags.isLivePhoto { badges.append(.livePhoto) }
            if photo.flags.personDetected { badges.append(.hasPeople) }
            if photo.quality.motionBlur > 0.6 || photo.quality.sharpness < 0.3 { badges.append(.blurry) }
            if protection.isProtected(photo.flags) { badges.append(.protected) }
            result[photo.id] = badges
        }
        return result
    }
}
