import Vision
import UIKit

/// Wraps Vision's image feature print — a learned descriptor that captures
/// visual content far better than a hash. Used as the second, higher-quality
/// stage after the perceptual-hash prefilter.
struct VisionFeaturePrintService {

    nonisolated func featurePrint(for image: UIImage) -> VNFeaturePrintObservation? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    /// Euclidean-style distance between two feature prints. Lower = more similar
    /// (≈0 identical). Returns nil if the prints are incompatible.
    nonisolated func distance(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Float? {
        var distance = Float(0)
        do {
            try a.computeDistance(&distance, to: b)
            return distance
        } catch {
            return nil
        }
    }
}
