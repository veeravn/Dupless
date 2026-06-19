import AppIntents
import Foundation

/// Run a conservative duplicate scan over recent photos (the safest default).
struct FindDuplicatePhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Duplicate Photos"
    static let description = IntentDescription("Scan your recent photos for duplicates, then open the app to review.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let request = ScanRequest(scope: .recent(limit: 300), options: .default, sensitivity: .conservative)
        IntentRouter.shared.request(.scan(request))
        return .result()
    }
}

/// Start a similarity scan for a chosen scope (album, date range, or recent).
struct FindSimilarPhotosIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Similar Photos"
    static let description = IntentDescription("Scan a chosen album or date range for similar photos.")
    static let openAppWhenRun = true

    @Parameter(title: "Album") var album: PhotoAlbumEntity?
    @Parameter(title: "From Date") var startDate: Date?
    @Parameter(title: "To Date") var endDate: Date?
    @Parameter(title: "Mode") var mode: DedupeModeAppEnum?
    @Parameter(title: "Include Screenshots") var includeScreenshots: Bool?

    @MainActor
    func perform() async throws -> some IntentResult {
        let scope: ScanScope
        if let album {
            scope = .album(localIdentifier: album.id)
        } else if let startDate, let endDate {
            scope = .dateRange(start: startDate, end: endDate)
        } else {
            scope = .recent(limit: 300)
        }
        let request = ScanRequest(
            scope: scope,
            options: ScanOptions(includeScreenshots: includeScreenshots ?? true, excludeFavorites: true),
            sensitivity: mode?.sensitivity ?? AppSettings.defaultSensitivity
        )
        IntentRouter.shared.request(.scan(request))
        return .result()
    }
}

/// Open the review screen for the existing duplicate groups.
struct ReviewDuplicateGroupsIntent: AppIntent {
    static let title: LocalizedStringResource = "Review Duplicate Groups"
    static let description = IntentDescription("Open the review screen for your duplicate groups.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.review)
        return .result()
    }
}

/// Resume an interrupted scan, or open the latest results.
struct ContinueLastScanIntent: AppIntent {
    static let title: LocalizedStringResource = "Continue Last Scan"
    static let description = IntentDescription("Resume an interrupted scan where it left off.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.resume)
        return .result()
    }
}

/// Create a best-shot review set from a date range or album (runs a scan so
/// keepers are ranked).
struct FindBestShotsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Best Shots"
    static let description = IntentDescription("Scan a date range or album and rank the best shots to review.")
    static let openAppWhenRun = true

    @Parameter(title: "Album") var album: PhotoAlbumEntity?
    @Parameter(title: "From Date") var startDate: Date?
    @Parameter(title: "To Date") var endDate: Date?

    @MainActor
    func perform() async throws -> some IntentResult {
        let scope: ScanScope
        if let album {
            scope = .album(localIdentifier: album.id)
        } else if let startDate, let endDate {
            scope = .dateRange(start: startDate, end: endDate)
        } else {
            scope = .recent(limit: 300)
        }
        IntentRouter.shared.request(.scan(ScanRequest(scope: scope, options: .default, sensitivity: .balanced)))
        return .result()
    }
}

/// Prepares for MVP 5 drone mode; for MVP 3 it maps to an aggressive
/// burst/recent-session scan.
struct FindBestDroneShotsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Best Drone Shots"
    static let description = IntentDescription("Scan recent burst-style photos for the best shots.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        IntentRouter.shared.request(.droneBurstScan(scope: .recent(limit: 500), options: .default))
        return .result()
    }
}
