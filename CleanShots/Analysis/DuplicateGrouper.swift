import Vision

/// Pure grouping logic: blocking → pairwise similarity → connected components.
/// No PhotoKit dependency, so it is fully unit-testable with synthetic inputs.
struct DuplicateGrouper {
    private let featureService = VisionFeaturePrintService()

    nonisolated func group(_ analyzed: [AnalyzedPhoto], sensitivity: SimilaritySensitivity) -> [ScanGroupResult] {
        guard !analyzed.isEmpty else { return [] }

        // Bucket by blocking key so we only compare plausibly-similar photos.
        var blocks: [String: [Int]] = [:]
        for (index, item) in analyzed.enumerated() {
            blocks[item.blockingKey, default: []].append(index)
        }

        var unionFind = UnionFind(count: analyzed.count)
        for indices in blocks.values {
            for i in 0..<indices.count {
                for j in (i + 1)..<indices.count {
                    let a = analyzed[indices[i]]
                    let b = analyzed[indices[j]]
                    guard PerceptualHashService.hammingDistance(a.hash, b.hash) <= sensitivity.hammingPrefilter
                    else { continue }
                    if distance(a, b) <= sensitivity.featureDistanceThreshold {
                        unionFind.union(indices[i], indices[j])
                    }
                }
            }
        }

        var components: [Int: [Int]] = [:]
        for index in 0..<analyzed.count {
            components[unionFind.find(index), default: []].append(index)
        }

        var results: [ScanGroupResult] = []
        for members in components.values where members.count > 1 {
            let ids = members.map { analyzed[$0].id }
            // Placeholder keeper for MVP 1: highest-resolution member (MVP 2 adds
            // real best-shot ranking).
            let keeper = members.max { analyzed[$0].pixelCount < analyzed[$1].pixelCount }
                .map { analyzed[$0].id }
            results.append(
                ScanGroupResult(
                    memberIdentifiers: ids,
                    confidence: confidence(of: members, in: analyzed),
                    keeperIdentifier: keeper
                )
            )
        }
        return results.sorted { $0.confidence > $1.confidence }
    }

    /// Vision feature-print distance when available, else a normalized Hamming
    /// fallback. Lower = more similar.
    nonisolated func distance(_ a: AnalyzedPhoto, _ b: AnalyzedPhoto) -> Float {
        if let fa = a.feature, let fb = b.feature, let d = featureService.distance(fa, fb) {
            return d
        }
        return Float(PerceptualHashService.hammingDistance(a.hash, b.hash)) / 64.0
    }

    nonisolated func confidence(of members: [Int], in analyzed: [AnalyzedPhoto]) -> Double {
        guard members.count > 1 else { return 1 }
        var total: Float = 0
        var pairs = 0
        for i in 0..<members.count {
            for j in (i + 1)..<members.count {
                total += distance(analyzed[members[i]], analyzed[members[j]])
                pairs += 1
            }
        }
        let average = pairs > 0 ? Double(total) / Double(pairs) : 0
        return min(0.99, max(0.5, 1 - average))
    }
}
