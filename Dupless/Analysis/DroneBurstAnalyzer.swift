import Foundation

/// The redundancy decision for one session cluster: which photos are the best
/// shots to keep, which are protected unique angles, and (derived) which are
/// redundant and suggested for removal.
struct SessionClusterResult: Sendable, Equatable {
    let memberIdentifiers: [String]
    let recommendedBestShotIds: [String]
    let protectedUniqueShotIds: [String]

    /// Members that are neither a best shot nor a protected unique angle.
    var suggestedRemovalIds: [String] {
        let kept = Set(recommendedBestShotIds).union(protectedUniqueShotIds)
        return memberIdentifiers.filter { !kept.contains($0) }
    }
}

/// Finds redundant sequences inside a session cluster and picks best shots while
/// protecting unique angles (MVP 5 Step 2). Pure — no PhotoKit. Visual
/// sub-grouping reuses `DuplicateGrouper`; ranking reuses `BestShotRanker`;
/// diversity uses `SceneDiversityScorer`. Altitudes (drone-like clusters only)
/// are passed in by the caller after a lazy `PhotoAltitudeService` lookup.
struct DroneBurstAnalyzer {
    /// Looser "drone sequence" similarity so slightly different angles still group
    /// (then diversity rescues the genuinely different ones).
    var sensitivity: SimilaritySensitivity
    var diversity: SceneDiversityScorer
    var policy: ProtectionPolicy

    init(
        sensitivity: SimilaritySensitivity = .balanced,
        diversity: SceneDiversityScorer = SceneDiversityScorer(),
        policy: ProtectionPolicy = .default
    ) {
        self.sensitivity = sensitivity
        self.diversity = diversity
        self.policy = policy
    }

    func analyze(_ analyses: [CachedAnalysis], altitudes: [String: Double] = [:]) -> SessionClusterResult {
        let memberIds = analyses.map(\.id)
        let byID = Dictionary(uniqueKeysWithValues: analyses.map { ($0.id, $0) })

        // Redundant sub-groups (size >= 2). Anything not in a sub-group is a
        // unique shot and is kept.
        let groups = DuplicateGrouper().group(analyses.map { $0.toAnalyzedPhoto() }, sensitivity: sensitivity)
        let grouped = Set(groups.flatMap { $0.memberIdentifiers })

        let engine = ProtectionPolicyEngine(policy: policy)
        let ranker = BestShotRanker(policy: policy)

        var bestShots: [String] = []
        var protectedUnique: Set<String> = analyses.filter { !grouped.contains($0.id) }.map(\.id).reduce(into: []) { $0.insert($1) }

        for group in groups {
            let rankables = group.memberIdentifiers.compactMap { byID[$0]?.rankablePhoto }
            let ranking = ranker.rank(rankables)
            guard let keeperID = ranking.keeperIdentifier, let keeper = byID[keeperID] else { continue }
            bestShots.append(keeperID)

            for id in group.memberIdentifiers where id != keeperID {
                guard let candidate = byID[id] else { continue }
                // Keep a non-keeper when it's protected by policy or contributes a
                // unique angle; otherwise it's redundant (suggested for removal).
                if engine.isProtected(candidate.flags)
                    || diversity.isUniqueAngle(
                        candidate: candidate.metadata,
                        keeper: keeper.metadata,
                        candidateAltitude: altitudes[id],
                        keeperAltitude: altitudes[keeperID]
                    ) {
                    protectedUnique.insert(id)
                }
            }
        }

        // Preserve original order for stable output.
        let protectedOrdered = memberIds.filter { protectedUnique.contains($0) && !bestShots.contains($0) }
        return SessionClusterResult(
            memberIdentifiers: memberIds,
            recommendedBestShotIds: bestShots,
            protectedUniqueShotIds: protectedOrdered
        )
    }
}
