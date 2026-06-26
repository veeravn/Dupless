import Foundation
import Photos

/// Computes the blocking key used to avoid all-to-all comparison: photos only
/// compare within the same capture-day + aspect-ratio bucket + screenshot flag.
enum BlockingKey {
    /// Pure, PhotoKit-free entry point (unit-testable).
    nonisolated static func make(
        creationDate: Date?,
        pixelWidth: Int,
        pixelHeight: Int,
        isScreenshot: Bool
    ) -> String {
        let day = creationDate.map { dayFormatter.string(from: $0) } ?? "nodate"
        let aspect = pixelHeight > 0
            ? Int((Double(pixelWidth) / Double(pixelHeight)) * 10)
            : 0
        return "\(day)|\(aspect)|\(isScreenshot ? "s" : "p")"
    }

    nonisolated static func make(for asset: PHAsset) -> String {
        make(
            creationDate: asset.creationDate,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            isScreenshot: asset.mediaSubtypes.contains(.photoScreenshot)
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-DDD"
        return formatter
    }()
}
