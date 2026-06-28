import Vision
import UIKit

/// Detects faces/people with Vision and, in the same pass, computes a feature
/// print for each face crop. Face *detection* runs on the Simulator too; the
/// per-face feature prints (like the whole-image ones) are device-only, so on
/// the Simulator `faceprints` comes back empty and the grouper falls back to a
/// face-*count* check. Used to protect photos with people (count) and to tell
/// whether two photos show the *same* people (prints).
struct FacePersonDetectionService {
    private let featureService = VisionFeaturePrintService()

    /// Cap on how many faces we print per photo. The largest (principal) faces
    /// are kept, so a crowd shot doesn't blow up storage or compute.
    static let maxFaces = 4

    struct Result {
        let faceCount: Int
        let personDetected: Bool
        /// Archived `VNFeaturePrintObservation` per detected face crop, largest
        /// face first, capped at `maxFaces`. Empty on Simulator / when faceless.
        let faceprints: [Data]
    }

    nonisolated func detect(in image: UIImage) -> Result {
        guard let cgImage = image.cgImage else {
            return Result(faceCount: 0, personDetected: false, faceprints: [])
        }
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            let faces = request.results ?? []
            return Result(faceCount: faces.count, personDetected: !faces.isEmpty,
                          faceprints: faceprints(for: faces, in: cgImage))
        } catch {
            return Result(faceCount: 0, personDetected: false, faceprints: [])
        }
    }

    /// Crops each face (largest first) and archives a feature print per crop.
    private nonisolated func faceprints(for faces: [VNFaceObservation], in cgImage: CGImage) -> [Data] {
        let ordered = faces
            .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
            .prefix(Self.maxFaces)
        var prints: [Data] = []
        for face in ordered {
            guard let crop = faceCrop(of: cgImage, normalized: face.boundingBox),
                  let print = featureService.featurePrint(for: UIImage(cgImage: crop))
                      .flatMap(FeaturePrintArchive.archive)
            else { continue }
            prints.append(print)
        }
        return prints
    }

    /// Converts a Vision normalized boundingBox (origin bottom-left) to a pixel
    /// rect (origin top-left), pads ~20% to capture the whole head, clamps to the
    /// image, and crops. Returns nil for degenerate boxes.
    private nonisolated func faceCrop(of cgImage: CGImage, normalized: CGRect) -> CGImage? {
        let w = CGFloat(cgImage.width), h = CGFloat(cgImage.height)
        // Vision Y is bottom-up; CGImage Y is top-down.
        var rect = CGRect(
            x: normalized.origin.x * w,
            y: (1 - normalized.origin.y - normalized.height) * h,
            width: normalized.width * w,
            height: normalized.height * h
        )
        rect = rect.insetBy(dx: -rect.width * 0.2, dy: -rect.height * 0.2)
            .intersection(CGRect(x: 0, y: 0, width: w, height: h))
        guard rect.width >= 8, rect.height >= 8 else { return nil }
        return cgImage.cropping(to: rect)
    }
}
