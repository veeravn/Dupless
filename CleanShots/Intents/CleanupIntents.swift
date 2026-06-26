import AppIntents
import SwiftData

/// Speak/show the latest scan summary. Read-only — does not open the app.
struct ShowCleanupSummaryIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Cleanup Summary"
    static let description = IntentDescription("Tell me about my latest duplicate scan.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let summary = CleanupSummary.text(in: SharedStore.container.mainContext)
        return .result(dialog: IntentDialog(stringLiteral: summary))
    }
}

/// Change the default cleanup mode. Switching to a more aggressive mode asks for
/// confirmation first (it suggests more removals).
struct ChangeCleanupModeIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Cleanup Mode"
    static let description = IntentDescription("Set how aggressively Dupless suggests removals.")

    @Parameter(title: "Mode") var mode: DedupeModeAppEnum

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        if mode == .aggressive || mode == .droneBurst {
            let name = DedupeModeAppEnum.caseDisplayRepresentations[mode]?.title ?? "this mode"
            try await requestConfirmation(
                dialog: "Switch to \(name) mode? It suggests more removals for you to review."
            )
        }
        AppSettings.defaultSensitivity = mode.sensitivity
        let name = DedupeModeAppEnum.caseDisplayRepresentations[mode]?.title ?? "\(mode.rawValue)"
        return .result(dialog: "Cleanup mode set to \(name).")
    }
}

/// Create a Photos album of the recommended keepers. Large albums are confirmed.
struct CreateBestShotsAlbumIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Best Shots Album"
    static let description = IntentDescription("Save the recommended best shots into a new album.")

    @Parameter(title: "Album Name", default: "Best Shots") var name: String

    static let confirmationThreshold = 50

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let identifiers = BestShotsCollector.keeperIdentifiers(in: SharedStore.container.mainContext)
        guard !identifiers.isEmpty else {
            return .result(dialog: "There are no best shots yet. Run a scan first.")
        }

        if identifiers.count > Self.confirmationThreshold {
            try await requestConfirmation(
                dialog: "Create an album with \(identifiers.count) best shots?"
            )
        }

        let result = await AlbumCreationService().createAlbum(named: name, assetIdentifiers: identifiers)
        switch result {
        case .success(let count):
            return .result(dialog: "Created “\(name)” with \(count) best shots.")
        case .empty:
            return .result(dialog: "No photos were available to add.")
        case .failed(let message):
            return .result(dialog: "Couldn't create the album: \(message)")
        }
    }
}

/// Explain why the keeper of the top group was recommended (template, non-LLM).
struct ExplainPhotoChoiceIntent: AppIntent {
    static let title: LocalizedStringResource = "Explain Photo Choice"
    static let description = IntentDescription("Explain why a photo was chosen as the keeper.")

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let explanation = KeeperExplanation.forTopGroup(in: SharedStore.container.mainContext) else {
            return .result(dialog: "There are no recommendations yet. Run a scan first.")
        }
        return .result(dialog: IntentDialog(stringLiteral: explanation))
    }
}
