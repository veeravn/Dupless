import Foundation

/// Conservative / Balanced / Aggressive similarity, as offered in ScanSetupView.
/// Controls how close two photos must be (by Vision feature-print distance) to
/// be treated as duplicates. Conservative is the default to minimize false
/// positives, per the safety guidance.
enum SimilaritySensitivity: String, CaseIterable, Identifiable, Sendable {
    case conservative
    case balanced
    case aggressive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced: return "Balanced"
        case .aggressive: return "Aggressive"
        }
    }

    var subtitle: String {
        switch self {
        case .conservative: return "Only near-identical photos"
        case .balanced: return "Similar photos (recommended)"
        case .aggressive: return "Loosely similar photos"
        }
    }

    /// Max Vision feature-print distance to consider two photos duplicates.
    var featureDistanceThreshold: Float {
        switch self {
        case .conservative: return 0.30
        case .balanced: return 0.55
        case .aggressive: return 0.80
        }
    }

    /// Generous Hamming prefilter (out of 64). The feature print is the real gate;
    /// this just avoids running Vision distance on obviously unrelated pairs.
    var hammingPrefilter: Int { 22 }

    /// Looser feature-print distance applied only to photos shot in the same short
    /// session (see `sessionWindow`). A pose change against the same backdrop
    /// raises whole-image distance past `featureDistanceThreshold`, so without
    /// this a "same background, different pose" series never groups. Gating on
    /// time (and location, when geotagged) keeps the relaxation from grouping
    /// unrelated look-alikes elsewhere in the library.
    var sessionRelaxedThreshold: Float {
        switch self {
        case .conservative: return 0.50
        case .balanced: return 0.75
        case .aggressive: return 0.92
        }
    }

    /// Photos taken within this window of each other are treated as one shooting
    /// session for the relaxed-grouping pass.
    static let sessionWindow: TimeInterval = 600

    /// When both photos are geotagged, the relaxed pass also requires them to be
    /// within this distance — a same-backdrop series is a single place.
    static let sessionProximityMeters: Double = 60
}

/// Standard union-find (disjoint set) for grouping similar photos into
/// connected components. Photo = node, similarity match = edge, group = component.
struct UnionFind {
    private var parent: [Int]
    private var rank: [Int]

    init(count: Int) {
        parent = Array(0..<count)
        rank = Array(repeating: 0, count: count)
    }

    mutating func find(_ x: Int) -> Int {
        var root = x
        while parent[root] != root { root = parent[root] }
        // Path compression.
        var node = x
        while parent[node] != root {
            let next = parent[node]
            parent[node] = root
            node = next
        }
        return root
    }

    mutating func union(_ a: Int, _ b: Int) {
        let ra = find(a), rb = find(b)
        guard ra != rb else { return }
        if rank[ra] < rank[rb] {
            parent[ra] = rb
        } else if rank[ra] > rank[rb] {
            parent[rb] = ra
        } else {
            parent[rb] = ra
            rank[ra] += 1
        }
    }
}
