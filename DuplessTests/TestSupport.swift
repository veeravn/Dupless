import UIKit
@testable import CleanShots

/// Image helpers for analysis tests. Patterns (not solid colors) are used where
/// a perceptual hash needs gradients to be meaningful.
enum TestImages {
    static func solid(_ color: UIColor, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Vertical split: left `a`, right `b` — strong horizontal gradient.
    static func verticalSplit(_ a: UIColor, _ b: UIColor, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            a.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size.width / 2, height: size.height))
            b.setFill(); ctx.fill(CGRect(x: size.width / 2, y: 0, width: size.width / 2, height: size.height))
        }
    }

    /// Horizontal split: top `a`, bottom `b`.
    static func horizontalSplit(_ a: UIColor, _ b: UIColor, size: CGSize = CGSize(width: 64, height: 64)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            a.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height / 2))
            b.setFill(); ctx.fill(CGRect(x: 0, y: size.height / 2, width: size.width, height: size.height / 2))
        }
    }

    /// A distinctive content image so Vision produces a stable feature print.
    static func patterned(seed: Int, size: CGSize = CGSize(width: 96, height: 96)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let colors: [UIColor] = [.red, .green, .blue, .orange, .purple]
            for i in 0..<6 {
                colors[(seed + i) % colors.count].setFill()
                let r = CGRect(x: CGFloat(i) * 14 + CGFloat(seed % 3) * 4, y: CGFloat((i * seed) % 60),
                               width: 24, height: 24)
                ctx.cgContext.fillEllipse(in: r)
            }
        }
    }
}

extension AnalyzedPhoto {
    /// Convenience for grouping tests: hash-only photo in a single shared block.
    static func make(id: String, hash: UInt64, pixelCount: Int = 1000, blockingKey: String = "block") -> AnalyzedPhoto {
        AnalyzedPhoto(id: id, pixelCount: pixelCount, blockingKey: blockingKey, hash: hash, feature: nil)
    }
}
