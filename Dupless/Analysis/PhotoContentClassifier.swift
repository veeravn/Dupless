import UIKit
import Vision

/// On-device image content classification, used to narrow a scan to a subject the
/// user named ("birthday", "beach", "dog"). Runs Vision's built-in classifier on
/// a thumbnail and matches its labels against the query. No network, no model
/// download — the classifier ships with the OS.
///
/// `matches(query:labels:)` is pure and unit-tested; the Vision call itself only
/// runs on device.
struct PhotoContentClassifier: Sendable {
    /// Minimum classifier confidence for a label to be considered.
    var minimumConfidence: Float = 0.1

    /// Content labels Vision assigns to an image, above the confidence floor.
    func labels(for image: UIImage) -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([request]) } catch { return [] }
        return (request.results ?? [])
            .filter { $0.confidence >= minimumConfidence }
            .map(\.identifier)
    }

    /// Whether a free-text content query is satisfied by an image's labels. A
    /// query token (3+ letters) matches when it's a substring of a label or vice
    /// versa, so "birthday" matches Vision's "birthday_cake". An empty query
    /// matches everything (no narrowing).
    func matches(query: String, labels: [String]) -> Bool {
        let tokens = query.lowercased()
            .split { !$0.isLetter }
            .map(String.init)
            .filter { $0.count >= 3 }
        guard !tokens.isEmpty else { return true }
        let normalized = labels.map { $0.lowercased() }
        return tokens.contains { token in
            normalized.contains { $0.contains(token) || token.contains($0) }
        }
    }
}
