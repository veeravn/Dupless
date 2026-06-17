import Vision
import UIKit

/// Detects faces/people with Vision. Unlike the feature-print model, face
/// detection runs on the simulator too. Used to protect photos with people.
struct FacePersonDetectionService {
    nonisolated func detect(in image: UIImage) -> (faceCount: Int, personDetected: Bool) {
        guard let cgImage = image.cgImage else { return (0, false) }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let count = request.results?.count ?? 0
            return (count, count > 0)
        } catch {
            return (0, false)
        }
    }
}
