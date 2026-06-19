import OSLog
import Photos
import SwiftData
import SwiftUI

private let scanLog = Logger(subsystem: "CleanShots", category: "scan")

/// Orchestrates a scan: fetch scope → analyze off-main (caching each result for
/// resume) → group → persist. Observable so ScanProgressView can react.
///
/// Resume: per-asset analysis is cached in `ImageFeatureRecord` and a
/// `ScanCheckpointRecord` tracks the in-flight scan. If the app is killed
/// mid-scan, the next run for the same scope reuses cached work and only
/// analyzes what's left.
@MainActor
@Observable
final class ScanEngine {
    private(set) var isScanning = false
    private(set) var stage: ScanStage?
    private(set) var progress: Double = 0
    private(set) var lastError: String?
    private(set) var lastResultCount = 0
    /// Photos in the scan that couldn't be analyzed (e.g. iCloud-only, not
    /// downloaded). Surfaced after a scan so skipped photos aren't hidden.
    private(set) var skippedCount = 0

    private let fetcher = PhotoAssetFetcher()
    private let loader = PhotoImageLoader()

    static let lastScanDateKey = "lastScanDate"

    // MARK: - Entry points

    /// Starts (or transparently resumes) a scan for a scope.
    func scan(
        scope: ScanScope,
        options: ScanOptions,
        sensitivity: SimilaritySensitivity,
        modelContext: ModelContext
    ) async {
        guard !isScanning else { return }

        let signature = "\(scope.signature)|\(options.signature)"
        stage = .indexing
        let fetchResult = fetcher.fetchAssets(scope: scope, options: options)
        var targets: [String] = []
        targets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in targets.append(asset.localIdentifier) }

        let checkpoint = upsertCheckpoint(
            signature: signature,
            scopeDescription: scope.displayName,
            sensitivity: sensitivity,
            targets: targets,
            in: modelContext
        )
        await run(checkpoint: checkpoint, sensitivity: sensitivity, modelContext: modelContext)
    }

    /// Runs a drone/burst scan: index + analyze (shared with the normal path),
    /// then cluster into sessions and pick best shots while protecting unique
    /// angles. Persists `SessionClusterRecord`s instead of duplicate groups.
    func scanDroneBurst(scope: ScanScope, options: ScanOptions, modelContext: ModelContext) async {
        guard !isScanning else { return }
        isScanning = true
        lastError = nil
        progress = 0
        skippedCount = 0
        stage = .indexing

        let signature = "drone|\(scope.signature)|\(options.signature)"
        let fetchResult = fetcher.fetchAssets(scope: scope, options: options)
        var targets: [String] = []
        targets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in targets.append(asset.localIdentifier) }

        let checkpoint = upsertCheckpoint(
            signature: signature,
            scopeDescription: scope.displayName,
            sensitivity: .balanced,
            targets: targets,
            in: modelContext
        )

        let allCached = await analyzePending(targets: checkpoint.targetIdentifiers, signature: signature, modelContext: modelContext)
        skippedCount = ScanCoverage.skippedCount(targets: checkpoint.targetIdentifiers, analyzed: allCached)

        stage = .finding
        let scanner = DroneBurstScanner(altitudeProvider: PhotoAltitudeService())
        let outcomes = await Task.detached(priority: .userInitiated) { await scanner.scan(allCached) }.value

        stage = .grouping
        persistClusters(outcomes.map(scanner.record), in: modelContext)

        stage = .preparing
        checkpoint.isComplete = true
        checkpoint.updatedAt = .now
        lastResultCount = outcomes.count
        try? modelContext.save()
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastScanDateKey)
        scanLog.log("drone/burst scan complete: \(outcomes.count) sessions")

        isScanning = false
        stage = nil
        progress = 1
    }

    /// Resumes a previously interrupted scan from its checkpoint.
    func resume(checkpoint: ScanCheckpointRecord, modelContext: ModelContext) async {
        guard !isScanning else { return }
        let sensitivity = SimilaritySensitivity(rawValue: checkpoint.sensitivityRaw) ?? .balanced
        await run(checkpoint: checkpoint, sensitivity: sensitivity, modelContext: modelContext)
    }

    /// The most recent unfinished scan, if any (drives the Resume affordance).
    func incompleteCheckpoint(in modelContext: ModelContext) -> ScanCheckpointRecord? {
        var descriptor = FetchDescriptor<ScanCheckpointRecord>(
            predicate: #Predicate { !$0.isComplete },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? modelContext.fetch(descriptor).first
    }

    // MARK: - Core run

    private func run(
        checkpoint: ScanCheckpointRecord,
        sensitivity: SimilaritySensitivity,
        modelContext: ModelContext
    ) async {
        isScanning = true
        lastError = nil
        progress = 0
        skippedCount = 0
        stage = .indexing

        let targets = checkpoint.targetIdentifiers
        let allCached = await analyzePending(targets: targets, signature: checkpoint.signature, modelContext: modelContext)
        skippedCount = ScanCoverage.skippedCount(targets: targets, analyzed: allCached)

        // Stage: group from the (now complete) cache, then rank each group to
        // pick the best-shot keeper (MVP 2). Both run off-main.
        stage = .finding
        let planner = DuplicateScanPlanner(sensitivity: sensitivity)
        let results = await Task.detached(priority: .userInitiated) { planner.plan(allCached) }.value

        stage = .grouping
        persistGroups(results, in: modelContext)

        stage = .preparing
        checkpoint.isComplete = true
        checkpoint.updatedAt = .now
        lastResultCount = results.count
        try? modelContext.save()
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastScanDateKey)
        scanLog.log("scan complete: \(results.count) groups")

        isScanning = false
        stage = nil
        progress = 1
    }

    /// Shared index→analyze stage: analyzes whatever isn't cached yet (persisting
    /// each result for resume) and returns the complete cached set for `targets`.
    private func analyzePending(targets: [String], signature: String, modelContext: ModelContext) async -> [CachedAnalysis] {
        let cachedIDs = Set(cachedAnalyses(for: targets, in: modelContext).map(\.id))
        let pending = ResumePlanner.pendingIdentifiers(targets: targets, cached: cachedIDs)
        scanLog.log("scan signature=\(signature) targets=\(targets.count) cached=\(cachedIDs.count) pending=\(pending.count)")

        if !pending.isEmpty {
            stage = .analyzing
            let analyzer = PhotoAnalyzer()
            let loaderRef = loader
            let total = pending.count
            let stream = AsyncStream<CachedAnalysis> { continuation in
                let task = Task.detached(priority: .userInitiated) {
                    for id in pending {
                        if let result = await analyzer.analyze(identifier: id, loader: loaderRef) {
                            continuation.yield(result)
                        }
                    }
                    continuation.finish()
                }
                continuation.onTermination = { _ in task.cancel() }
            }

            var done = 0
            for await analysis in stream {
                persistFeature(analysis, in: modelContext)
                done += 1
                progress = Double(done) / Double(total)
            }
        }
        return cachedAnalyses(for: targets, in: modelContext)
    }

    // MARK: - Persistence helpers

    private func cachedAnalyses(for identifiers: [String], in context: ModelContext) -> [CachedAnalysis] {
        guard !identifiers.isEmpty else { return [] }
        let wanted = Set(identifiers)
        let descriptor = FetchDescriptor<ImageFeatureRecord>(
            predicate: #Predicate { wanted.contains($0.assetLocalIdentifier) }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.map(\.cachedAnalysis)
    }

    private func persistFeature(_ analysis: CachedAnalysis, in context: ModelContext) {
        // Upsert by unique identifier.
        let id = analysis.id
        let descriptor = FetchDescriptor<ImageFeatureRecord>(
            predicate: #Predicate { $0.assetLocalIdentifier == id }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.perceptualHashBits = analysis.hashBits
            existing.featurePrintData = analysis.featurePrintData
            existing.blockingKey = analysis.blockingKey
            existing.pixelCount = analysis.pixelCount
            existing.quality = analysis.quality
            existing.flags = analysis.flags
            existing.computedAt = .now
        } else {
            context.insert(ImageFeatureRecord(cached: analysis))
        }
        try? context.save()
    }

    private func upsertCheckpoint(
        signature: String,
        scopeDescription: String,
        sensitivity: SimilaritySensitivity,
        targets: [String],
        in context: ModelContext
    ) -> ScanCheckpointRecord {
        let descriptor = FetchDescriptor<ScanCheckpointRecord>(
            predicate: #Predicate { $0.signature == signature }
        )
        if let existing = try? context.fetch(descriptor).first {
            existing.targetIdentifiers = targets
            existing.scopeDescription = scopeDescription
            existing.sensitivityRaw = sensitivity.rawValue
            existing.isComplete = false
            existing.updatedAt = .now
            try? context.save()
            return existing
        }
        let checkpoint = ScanCheckpointRecord(
            signature: signature,
            scopeDescription: scopeDescription,
            sensitivityRaw: sensitivity.rawValue,
            targetIdentifiers: targets
        )
        context.insert(checkpoint)
        try? context.save()
        return checkpoint
    }

    private func persistClusters(_ records: [SessionClusterRecord], in context: ModelContext) {
        do { try ScanResultWriter.replaceClusters(records, in: context) }
        catch { lastError = error.localizedDescription }
    }

    private func persistGroups(_ results: [ScanGroupResult], in context: ModelContext) {
        do { try ScanResultWriter.replaceGroups(results, in: context) }
        catch { lastError = error.localizedDescription }
    }
}
