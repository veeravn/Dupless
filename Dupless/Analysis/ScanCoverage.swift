import Foundation

/// How many of a scan's target photos couldn't be analyzed — typically because
/// they're in iCloud and not downloaded locally (analysis runs on-device with
/// networking off, so those assets are skipped rather than downloaded). Surfacing
/// this keeps the scan honest instead of silently ignoring photos.
enum ScanCoverage {
    static func skippedCount(targets: [String], analyzed: [CachedAnalysis]) -> Int {
        let analyzedIDs = Set(analyzed.map(\.id))
        let covered = targets.reduce(into: 0) { count, id in
            if analyzedIDs.contains(id) { count += 1 }
        }
        return max(0, targets.count - covered)
    }
}
