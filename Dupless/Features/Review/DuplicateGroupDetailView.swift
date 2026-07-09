import Photos
import SwiftData
import SwiftUI

/// Review a single group with MVP 2 smart ranking: a recommended best-shot
/// keeper, quality badges, protection reasons, and a protection-aware default
/// selection. Every choice is overridable (manual review required).
struct DuplicateGroupDetailView: View {
    let group: DuplicateGroupRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var assets: [PHAsset] = []
    @State private var ranking: GroupRanking?
    @State private var removalSelection: Set<String> = []
    @State private var showConfirmation = false
    @State private var inspecting: InspectorTarget?

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let keeperID = ranking?.keeperIdentifier, let badges = ranking?.badges[keeperID] {
                    KeeperExplanationPanel(group: group, templateText: RecommendationText.keeperSummary(badges: badges))
                }

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        let id = asset.localIdentifier
                        PhotoChoiceCell(
                            asset: asset,
                            isKeeper: id == ranking?.keeperIdentifier,
                            isMarkedForRemoval: removalSelection.contains(id),
                            badges: ranking?.badges[id] ?? [],
                            onToggle: { toggle(id) },
                            onInspect: { inspecting = InspectorTarget(startID: id) }
                        )
                    }
                }
            }
            .padding()
        }
        .navigationTitle("\(Int(group.confidence * 100))% Match")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showConfirmation) {
            CleanupConfirmationView(count: removalSelection.count) {
                await performCleanup()
            }
            .presentationDetents([.medium])
        }
        .fullScreenCover(item: $inspecting) { target in
            PhotoInspectorView(
                identifiers: assets.map(\.localIdentifier),
                keeperID: ranking?.keeperIdentifier,
                removalSelection: $removalSelection,
                startID: target.startID
            )
        }
        .task { await loadRanking() }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 6) {
            if protectedCount > 0 {
                Label("\(protectedCount) protected and kept", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Text(removalSelection.isEmpty
                     ? "Select photos to remove"
                     : "Move \(removalSelection.count) to Recently Deleted")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(removalSelection.isEmpty)
        }
        .padding()
        .background(.bar)
    }

    private var protectedCount: Int { ranking?.protectedIdentifiers.count ?? 0 }

    private func toggle(_ id: String) {
        if removalSelection.contains(id) { removalSelection.remove(id) }
        else { removalSelection.insert(id) }
    }

    private func loadRanking() async {
        assets = AssetResolver.assets(for: group.memberIdentifiers)
        let cached = cachedAnalyses(for: group.memberIdentifiers)
        let rankables = group.memberIdentifiers.compactMap { cached[$0]?.rankablePhoto }
        let result = BestShotRanker(policy: AppSettings.protectionPolicy).rank(rankables)
        ranking = result
        // Protection-aware default: pre-select only the suggested (non-protected) removals.
        removalSelection = Set(result.suggestedRemovalIdentifiers)
    }

    private func cachedAnalyses(for ids: [String]) -> [String: CachedAnalysis] {
        let wanted = Set(ids)
        let descriptor = FetchDescriptor<ImageFeatureRecord>(
            predicate: #Predicate { wanted.contains($0.assetLocalIdentifier) }
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: records.map { ($0.assetLocalIdentifier, $0.cachedAnalysis) })
    }

    private func performCleanup() async -> PhotoMutationService.Result {
        let result = await PhotoMutationService().moveToRecentlyDeleted(Array(removalSelection))
        if result == .success {
            modelContext.delete(group)
            try? modelContext.save()
            dismiss()
        }
        return result
    }
}

/// The keeper recommendation, with a "Why this one?" action that loads a richer,
/// model-generated explanation when Apple Intelligence is available. Falls back
/// to the same template wording otherwise, so the panel always works.
private struct KeeperExplanationPanel: View {
    let group: DuplicateGroupRecord
    let templateText: String

    @Environment(\.modelContext) private var modelContext
    @State private var aiText: String?
    @State private var loading = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecommendationCard(text: aiText ?? templateText)
            if aiText == nil {
                Button(action: load) {
                    Label(loading ? "Thinking…" : "Why this one?", systemImage: "sparkles")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .disabled(loading)
            }
        }
    }

    private func load() {
        loading = true
        Task {
            aiText = await AIExplanationService().explain(group, in: modelContext)
            loading = false
        }
    }
}

/// The recommendation summary banner above the grid.
private struct RecommendationCard: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "star.circle.fill")
                .foregroundStyle(.green)
                .font(.title3)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// A photo tile with keeper/remove state and a quality-badge strip.
private struct PhotoChoiceCell: View {
    let asset: PHAsset
    let isKeeper: Bool
    let isMarkedForRemoval: Bool
    let badges: [QualityBadge]
    let onToggle: () -> Void
    let onInspect: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            // Two sibling buttons: tapping the tile toggles keep/remove (as
            // before), while the corner magnifier opens the full-screen
            // inspector. Siblings (not nested) keep their hit areas distinct.
            ZStack(alignment: .bottomTrailing) {
                Button(action: onToggle) { thumbnail }
                    .buttonStyle(.plain)

                Button(action: onInspect) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(7)
                        .background(.black.opacity(0.45), in: Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .accessibilityLabel("View larger")
            }

            BadgeStrip(badges: badges)
        }
    }

    private var thumbnail: some View {
        AssetThumbnailView(asset: asset, targetSize: CGSize(width: 240, height: 240))
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: 3)
            }
            .overlay(alignment: .topLeading) {
                if isKeeper { Badge(text: "Keeper", systemImage: "star.fill", tint: .green) }
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: isMarkedForRemoval ? "minus.circle.fill" : "checkmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, isMarkedForRemoval ? .red : .green)
                    .padding(6)
            }
            .opacity(isMarkedForRemoval ? 0.55 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(.isButton)
            .accessibilityAddTraits(isMarkedForRemoval ? [.isSelected] : [])
            .accessibilityHint(isMarkedForRemoval ? "Double tap to keep this photo"
                                                   : "Double tap to mark this photo for removal")
    }

    private var accessibilityLabel: String {
        var parts = ["Photo"]
        if isKeeper { parts.append("recommended keeper") }
        parts.append(isMarkedForRemoval ? "marked for removal" : "kept")
        if !badges.isEmpty { parts.append(badges.map(\.rawValue).joined(separator: ", ")) }
        return parts.joined(separator: ", ")
    }

    private var borderColor: Color {
        if isMarkedForRemoval { return .red }
        if isKeeper { return .green }
        return .clear
    }
}

/// Compact horizontal strip of badge icons under a tile.
private struct BadgeStrip: View {
    let badges: [QualityBadge]
    var body: some View {
        HStack(spacing: 4) {
            ForEach(badges, id: \.self) { badge in
                Image(systemName: badge.systemImage)
                    .font(.caption2)
                    .foregroundStyle(badge == .protected ? Color.orange
                                     : badge.isNegative ? Color.red : Color.secondary)
                    .accessibilityLabel(badge.rawValue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 14)
        // The tile's own label already enumerates these badges; hiding the strip
        // avoids VoiceOver announcing every badge a second time.
        .accessibilityHidden(true)
    }
}

private struct Badge: View {
    let text: String
    let systemImage: String
    let tint: Color
    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(tint, in: Capsule())
            .foregroundStyle(.white)
            .padding(6)
    }
}
