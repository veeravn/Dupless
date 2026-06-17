import UIKit

/// Computes per-image quality metrics from a thumbnail in a single grayscale
/// pass: sharpness (Laplacian energy), contrast (luminance spread), exposure
/// (balance + clipping), and a motion-blur estimate. On-device, no uploads.
///
/// Absolute calibration isn't critical — the ranker compares photos *within* a
/// group, so relative ordering is what matters.
struct QualityScoringService {
    private let dim = 64

    nonisolated func scores(for image: UIImage) -> QualityScores {
        guard let cgImage = image.cgImage else { return .unknown }

        let count = dim * dim
        var pixels = [UInt8](repeating: 0, count: count)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let context = CGContext(
            data: &pixels, width: dim, height: dim, bitsPerComponent: 8,
            bytesPerRow: dim, space: colorSpace, bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return .unknown }
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dim, height: dim))

        let lum = pixels.map { Double($0) / 255.0 }
        let mean = lum.reduce(0, +) / Double(count)
        let variance = lum.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(count)
        let std = variance.squareRoot()

        // Sharpness: mean squared Laplacian response over interior pixels.
        var laplacianEnergy = 0.0
        for y in 1..<(dim - 1) {
            for x in 1..<(dim - 1) {
                let i = y * dim + x
                let lap = 4 * lum[i] - lum[i - 1] - lum[i + 1] - lum[i - dim] - lum[i + dim]
                laplacianEnergy += lap * lap
            }
        }
        let interior = Double((dim - 2) * (dim - 2))
        let sharpnessRaw = laplacianEnergy / interior

        // Exposure: penalize deviation from mid-gray and clipped pixels.
        let clippedLow = Double(pixels.lazy.filter { $0 < 4 }.count) / Double(count)
        let clippedHigh = Double(pixels.lazy.filter { $0 > 251 }.count) / Double(count)
        let midDeviation = abs(mean - 0.5) * 2

        let sharpness = clamp01(sharpnessRaw * 25)
        let contrast = clamp01(std * 3.2)
        let exposure = clamp01(1.0 - midDeviation * 0.6 - (clippedLow + clippedHigh) * 0.8)
        let motionBlur = clamp01(1.0 - sharpness)

        return QualityScores(sharpness: sharpness, exposure: exposure, contrast: contrast, motionBlur: motionBlur)
    }

    private nonisolated func clamp01(_ x: Double) -> Double { min(1.0, max(0.0, x)) }
}
