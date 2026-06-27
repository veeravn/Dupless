import Foundation
import OSLog
import Vision

/// Pure grouping logic: blocking → pairwise similarity → connected components.
/// No PhotoKit dependency, so it is fully unit-testable with synthetic inputs.
struct DuplicateGrouper {
    private let featureService = VisionFeaturePrintService()

    /// DEBUG-only log of per-pair grouping decisions, for tuning thresholds from
    /// real photos. Off by default; enable by setting the `CLEANSHOTS_GROUP_LOG`
    /// environment variable in the Run scheme. View in Xcode/Console with
    /// subsystem "Dupless", category "grouping". Logs ids/distances only —
    /// never image content.
    private static let log = Logger(subsystem: "Dupless", category: "grouping")
    private static let pairLoggingEnabled =
        ProcessInfo.processInfo.environment["CLEANSHOTS_GROUP_LOG"] != nil

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
                    let hamming = PerceptualHashService.hammingDistance(a.hash, b.hash)
                    let withinPrefilter = hamming <= sensitivity.hammingPrefilter
                    let session = sameSession(a, b)
                    #if DEBUG
                    logPair(a, b, hamming: hamming, withinPrefilter: withinPrefilter,
                            session: session, sensitivity: sensitivity)
                    #endif
                    // The Hamming prefilter only gates the strict path. A pose
                    // change can shift the perceptual hash past it, so same-session
                    // pairs skip the prefilter and get a real feature-distance check
                    // — otherwise a same-backdrop series never even reaches it.
                    guard withinPrefilter || session else { continue }
                    // Photos with clearly different numbers of people are different
                    // compositions — "just the couple" vs "the whole family" at the
                    // same party backdrop — not duplicates. Never merge them,
                    // however similar the background looks.
                    guard compatibleComposition(a, b) else { continue }
                    let d = distance(a, b)
                    if withinPrefilter, d <= sensitivity.featureDistanceThreshold {
                        unionFind.union(indices[i], indices[j])
                    } else if session, d <= sensitivity.sessionRelaxedThreshold,
                              similarColor(a, b) {
                        // Same shooting session: a pose change against the same
                        // backdrop still groups, so the series collapses to one
                        // keeper instead of staying ungrouped. The color gate keeps
                        // this relaxed merge from swallowing a same-backdrop shot
                        // whose subject changed color (e.g. an outfit change) — the
                        // grayscale hash and feature print under-weight that, so the
                        // coarse color histogram catches it. Gating only this path
                        // never weakens the strict true-duplicate match above.
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

    #if DEBUG
    /// Logs one pair's grouping signals when they're plausibly related (same
    /// session, or feature distance within a generous bound). Lets us read the
    /// real hamming/feature distances for a series that isn't grouping and tune
    /// `featureDistanceThreshold` / `sessionRelaxedThreshold` from data.
    private func logPair(_ a: AnalyzedPhoto, _ b: AnalyzedPhoto, hamming: Int,
                         withinPrefilter: Bool, session: Bool, sensitivity: SimilaritySensitivity) {
        guard Self.pairLoggingEnabled else { return }
        let d = distance(a, b)
        guard session || d <= 1.0 else { return }
        let gap = a.captureDate.flatMap { ca in b.captureDate.map { abs(ca.timeIntervalSince($0)) } } ?? -1
        let composition = compatibleComposition(a, b)
        let color = colorSimilarity(a, b) ?? -1
        let grouped = composition
            && ((withinPrefilter && d <= sensitivity.featureDistanceThreshold)
                || (session && d <= sensitivity.sessionRelaxedThreshold && similarColor(a, b)))
        let line = String(
            format: "%@ × %@  hamming=%d  feat=%.3f  gapSec=%.0f  faces=%d/%d  color=%.2f  session=%@  prefilter=%@  → %@",
            String(a.id.prefix(6)), String(b.id.prefix(6)), hamming, d, gap,
            a.faceCount, b.faceCount, color,
            session ? "Y" : "N", withinPrefilter ? "Y" : "N", grouped ? "GROUP" : "skip")
        Self.log.debug("\(line, privacy: .public)")
    }
    #endif

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

    /// Two photos whose detected face counts differ by more than
    /// `maxFaceCountDelta` are treated as distinct compositions and never grouped,
    /// even when visually near-identical. A ±1 difference is tolerated to absorb
    /// face-detection flicker across a burst of the same people; a larger gap
    /// (a couple vs a crowd) blocks grouping. Photos with no detected faces
    /// (0 vs 0, e.g. landscapes) are unaffected.
    nonisolated func compatibleComposition(_ a: AnalyzedPhoto, _ b: AnalyzedPhoto) -> Bool {
        abs(a.faceCount - b.faceCount) <= Self.maxFaceCountDelta
    }

    /// Max difference in detected face count for two photos to still be groupable.
    static let maxFaceCountDelta = 1

    /// Whether two photos are close enough in overall color for the relaxed
    /// same-session merge. Returns true when either lacks a color signature (older
    /// cache, or a thumbnail that couldn't be rasterized) so the fix never
    /// regresses photos analyzed before it shipped — they fall back to the visual
    /// signals exactly as before. Otherwise requires histogram-intersection
    /// similarity at or above `colorSimilarityFloor`.
    nonisolated func similarColor(_ a: AnalyzedPhoto, _ b: AnalyzedPhoto) -> Bool {
        guard let sim = colorSimilarity(a, b) else { return true }
        return sim >= Self.colorSimilarityFloor
    }

    /// Histogram-intersection similarity of two color signatures, in 0...1 (1 =
    /// identical color distribution). Each signature is 64 bins normalized to a
    /// 0...255 byte; intersection sums the per-bin minimum and divides by the
    /// smaller signature's total, so it's robust to the two not summing to exactly
    /// the same value. Returns nil when either signature is missing or malformed.
    nonisolated func colorSimilarity(_ a: AnalyzedPhoto, _ b: AnalyzedPhoto) -> Float? {
        guard let sa = a.colorSignature, let sb = b.colorSignature,
              sa.count == sb.count, !sa.isEmpty else { return nil }
        var intersection = 0
        var totalA = 0
        var totalB = 0
        for i in 0..<sa.count {
            let va = Int(sa[i])
            let vb = Int(sb[i])
            intersection += min(va, vb)
            totalA += va
            totalB += vb
        }
        let denominator = min(totalA, totalB)
        guard denominator > 0 else { return nil }
        return Float(intersection) / Float(denominator)
    }

    /// Minimum color-histogram similarity (0...1) for two same-session photos to
    /// still merge on the relaxed path. Conservative by design: high enough to
    /// split an outfit/subject color change against a shared backdrop, low enough
    /// that lighting/white-balance drift or a flash/no-flash pair of the *same*
    /// scene still groups. Surfaced in the DEBUG `CLEANSHOTS_GROUP_LOG` (the
    /// `color=` field) so it can be tuned against real photos.
    static let colorSimilarityFloor: Float = 0.6

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
