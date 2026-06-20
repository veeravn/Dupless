import Foundation

/// Within an already-grouped set of similar photos, separates *near-identical
/// frames* — the same shot captured more than once, a true redundant duplicate —
/// from *distinct variations*: the same scene or background with a different pose
/// or composition. Only near-identical frames are suggested for removal by
/// default; distinct variations are kept for the user to review, so e.g. a series
/// of "same backdrop, different pose" portraits isn't pre-marked for deletion.
///
/// Pure over `AnalyzedPhoto` (feature print + hash), so it's unit-testable
/// without PhotoKit. Reuses `DuplicateGrouper`'s feature-print/Hamming distance.
struct RedundancyClassifier {
    /// Maximum distance from the keeper for a member to count as a near-identical
    /// frame. Deliberately tighter than any grouping threshold in
    /// `SimilaritySensitivity`, so a pose change (which alters a large part of the
    /// frame) lands outside it and is treated as a distinct shot to review.
    var redundantDistance: Float = 0.22

    private let grouper = DuplicateGrouper()

    /// Ids of members that are near-identical to the keeper — the default removal
    /// set. The keeper itself and any distinct variations are omitted.
    func redundantIdentifiers(members: [AnalyzedPhoto], keeperID: String?) -> Set<String> {
        guard let keeperID, let keeper = members.first(where: { $0.id == keeperID }) else { return [] }
        var redundant: Set<String> = []
        for member in members where member.id != keeperID {
            if grouper.distance(keeper, member) <= redundantDistance {
                redundant.insert(member.id)
            }
        }
        return redundant
    }
}
