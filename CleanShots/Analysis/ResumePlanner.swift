/// Determines what work remains when resuming an interrupted scan: the target
/// identifiers that have not yet been analyzed (cached). Order of `targets` is
/// preserved so resume continues roughly where it left off.
enum ResumePlanner {
    nonisolated static func pendingIdentifiers(targets: [String], cached: Set<String>) -> [String] {
        targets.filter { !cached.contains($0) }
    }

    /// Whether a scan with these targets is already fully analyzed.
    nonisolated static func isComplete(targets: [String], cached: Set<String>) -> Bool {
        pendingIdentifiers(targets: targets, cached: cached).isEmpty
    }
}
