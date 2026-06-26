import UIKit

/// Generates a 64-bit difference hash (dHash) from a thumbnail.
///
/// dHash downscales to 9×8 grayscale and records, for each row, whether each
/// pixel is brighter than its right neighbor — 8×8 = 64 comparison bits. It is
/// cheap, robust to resave/recompression, and gives a fast Hamming-distance
/// prefilter before the more expensive Vision feature print.
struct PerceptualHashService {
    private let width = 9
    private let height = 8

    nonisolated func hash(for image: UIImage) -> UInt64? {
        guard let cgImage = image.cgImage else { return nil }

        let pixelCount = width * height
        var pixels = [UInt8](repeating: 0, count: pixelCount)
        let colorSpace = CGColorSpaceCreateDeviceGray()

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return nil }

        context.interpolationQuality = .low
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var hash: UInt64 = 0
        var bit: UInt64 = 0
        for row in 0..<height {
            for col in 0..<(width - 1) {
                let left = pixels[row * width + col]
                let right = pixels[row * width + col + 1]
                if left > right {
                    hash |= (1 << bit)
                }
                bit += 1
            }
        }
        return hash
    }

    /// Number of differing bits between two hashes (0 = identical, 64 = opposite).
    nonisolated static func hammingDistance(_ a: UInt64, _ b: UInt64) -> Int {
        (a ^ b).nonzeroBitCount
    }
}
