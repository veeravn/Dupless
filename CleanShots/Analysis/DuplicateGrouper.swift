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
                    let d = distance(a, b)
                    if d <= sensitivity.featureDistanceThreshold {
                        unionFind.union(indices[i], indices[j])
                    } else if d <= sensitivity.sessionRelaxedThreshold, sameSession(a, b) {
                        // Same shooting session: a pose change against the same
                        // backdrop still groups, so the series collapses to one
                        // keeper instead of staying ungrouped.
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

    /// Whether two photos belong to the same short shooting session — taken
    /// within `sessionWindow` and, when both are geotagged, within
    /// `sessionProximityMeters`. Gates the relaxed-grouping pass so a
    /// same-backdrop series of different poses can group without loosening
    /// similarity across the whole library. False when either lacks a capture
    /// date (then only the strict visual threshold applies).
    nonisolated func sameSession(_ a: AnalyzedPhoto, _ b: AnalyzedPhoto) -> Bool {
        guard let da = a.captureDate, let db = b.captureDate,
              abs(da.timeIntervalSince(db)) <= SimilaritySensitivity.sessionWindow
        else { return false }
        if let alat = a.latitude, let alon = a.longitude,
           let blat = b.latitude, let blon = b.longitude {
            return GeoDistance.meters(lat1: alat, lon1: alon, lat2: blat, lon2: blon)
                <= SimilaritySensitivity.sessionProximityMeters
        }
        return true
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
