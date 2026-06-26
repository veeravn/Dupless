import AppIntents

/// Registers Siri phrases / Shortcuts actions for the app's intents. Limited to
/// the most common, safe entry points (no direct deletion via voice).
struct DuplessShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindDuplicatePhotosIntent(),
            phrases: [
                "Find duplicate photos in \(.applicationName)",
                "Find duplicates with \(.applicationName)",
            ],
            shortTitle: "Find Duplicates",
            systemImageName: "rectangle.stack.badge.minus"
        )
        AppShortcut(
            intent: FindSimilarPhotosIntent(),
            phrases: [
                "Find similar photos in \(.applicationName)",
                "Scan for similar photos with \(.applicationName)",
            ],
            shortTitle: "Find Similar",
            systemImageName: "square.on.square"
        )
        AppShortcut(
            intent: ReviewDuplicateGroupsIntent(),
            phrases: [
                "Review my duplicate groups in \(.applicationName)",
                "Review duplicates in \(.applicationName)",
            ],
            shortTitle: "Review Duplicates",
            systemImageName: "rectangle.stack"
        )
        AppShortcut(
            intent: FindBestShotsIntent(),
            phrases: [
                "Find the best photos in \(.applicationName)",
                "Find best shots with \(.applicationName)",
            ],
            shortTitle: "Find Best Shots",
            systemImageName: "star"
        )
        AppShortcut(
            intent: CreateBestShotsAlbumIntent(),
            phrases: [
                "Make an album of the best shots in \(.applicationName)",
                "Create a best shots album in \(.applicationName)",
            ],
            shortTitle: "Best Shots Album",
            systemImageName: "star.square.on.square"
        )
        AppShortcut(
            intent: ContinueLastScanIntent(),
            phrases: [
                "Continue my last photo scan in \(.applicationName)",
                "Resume my scan in \(.applicationName)",
            ],
            shortTitle: "Continue Scan",
            systemImageName: "arrow.clockwise"
        )
        AppShortcut(
            intent: ShowCleanupSummaryIntent(),
            phrases: [
                "Show my cleanup summary in \(.applicationName)",
                "What did \(.applicationName) find",
            ],
            shortTitle: "Cleanup Summary",
            systemImageName: "list.bullet.clipboard"
        )
        AppShortcut(
            intent: ExplainPhotoChoiceIntent(),
            phrases: [
                "Explain why this photo was chosen in \(.applicationName)",
                "Why did \(.applicationName) keep this photo",
            ],
            shortTitle: "Explain Choice",
            systemImageName: "text.bubble"
        )
        AppShortcut(
            intent: ChangeCleanupModeIntent(),
            phrases: [
                "Change cleanup mode in \(.applicationName)",
                "Make cleanup more conservative in \(.applicationName)",
            ],
            shortTitle: "Change Mode",
            systemImageName: "slider.horizontal.3"
        )
    }
}
