import Foundation

/// Drives the natural-language scan bar: holds the query, the parsed result
/// awaiting confirmation, and the confirm/cancel actions. Kept separate from the
/// SwiftUI view so the behavior is unit-testable.
///
/// Safety: parsing only *proposes* a scan. Nothing runs until `confirm()`, which
/// routes to the normal scan flow (and thus manual review) — the model never
/// deletes.
@MainActor
@Observable
final class NaturalLanguageScanModel {
    var query: String = ""
    var isParsing = false
    /// Non-nil when a parsed scan is awaiting the user's confirmation; drives the
    /// resolved-settings sheet.
    var pending: ParsedScan?

    private let coordinator: NaturalLanguageScanCoordinator
    private let router: IntentRouter

    init(coordinator: NaturalLanguageScanCoordinator, router: IntentRouter) {
        self.coordinator = coordinator
        self.router = router
    }

    /// Uses the shared router and the default (model-or-template) coordinator.
    /// The delegating body is main-actor isolated, so `.shared` is safe here.
    convenience init() {
        self.init(coordinator: NaturalLanguageScanCoordinator(), router: .shared)
    }

    var canSubmit: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isParsing
    }

    /// Parses the current query and stages the result for confirmation.
    func submit() async {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isParsing = true
        pending = await coordinator.parse(text)
        isParsing = false
    }

    /// Confirms the staged scan: routes to it and clears the bar.
    func confirm() {
        guard let pending else { return }
        router.request(.scan(pending.toScanRequest()))
        self.pending = nil
        query = ""
    }

    /// Dismisses the staged scan without running it.
    func cancel() {
        pending = nil
    }
}
