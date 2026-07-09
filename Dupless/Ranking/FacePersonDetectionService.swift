import CoreImage
import Vision
import UIKit

/// Detects faces/people with Vision and, separately, computes a feature print per
/// face crop for identity matching.
///
/// `detect` runs on the small analysis thumbnail (cheap; also works on the
/// Simulator) for the count + protection signal. `faceprints` must be given a
/// HIGHER-RESOLUTION render: in the 256px thumbnail a face is only ~15–40px, far
/// too small for the feature print to tell people apart (measured — the same- and
/// different-person distance populations overlap completely at that size). Like
/// the whole-image feature print, the per-face prints are device-only, so on the
/// Simulator `faceprints` returns empty and the grouper falls back to face count.
struct FacePersonDetectionService {
    private let featureService = VisionFeaturePrintService()

    /// Cap on how many faces we print per photo. The largest (principal) faces are
    /// kept, so a crowd shot doesn't blow up storage or compute.
    static let maxFaces = 4

    /// Cheap count/protection signal from the analysis thumbnail.
    nonisolated func detect(in image: UIImage) -> (faceCount: Int, personDetected: Bool) {
        guard let cgImage = Self.cgImage(from: image) else { return (0, false) }
        let count = detectFaces(in: cgImage).count
        return (count, count > 0)
    }

    /// Per-face feature prints (largest faces first, capped at `maxFaces`),
    /// archived for caching. Pass a high-resolution render — see the type note.
    /// Empty on the Simulator / when faceless.
    nonisolated func faceprints(in image: UIImage) -> [Data] {
        guard let cgImage = Self.cgImage(from: image) else { return [] }
        let ordered = detectFaces(in: cgImage)
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

    /// A CGImage for Vision. PHImageManager usually returns CGImage-backed
    /// UIImages, but a CIImage-backed one (`.cgImage == nil`) would silently yield
    /// zero face prints, so fall back to rendering the CIImage.
    private nonisolated static func cgImage(from image: UIImage) -> CGImage? {
        if let cg = image.cgImage { return cg }
        guard let ci = image.ciImage else { return nil }
        return CIContext().createCGImage(ci, from: ci.extent)
    }

    private nonisolated func detectFaces(in cgImage: CGImage) -> [VNFaceObservation] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try? handler.perform([request])
        return request.results ?? []
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
