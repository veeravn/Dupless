import Photos
import SwiftData
import SwiftUI

/// Drone/burst results: a session summary plus a row per detected sequence.
struct SessionClusterListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SessionClusterRecord.startDate, order: .reverse) private var clusters: [SessionClusterRecord]

    var body: some View {
        List {
            if !clusters.isEmpty {
                Section {
                    Text(SessionSummaryGenerator().summarize(SessionStatsBuilder.make(in: modelContext)))
                        .font(.subheadline)
                }
                Section("Sessions") {
                    ForEach(clusters) { cluster in
                        NavigationLink {
                            SessionClusterDetailView(cluster: cluster)
                        } label: {
                            SessionRow(cluster: cluster)
                        }
                    }
                }
            }
        }
        .navigationTitle("Sessions")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if clusters.isEmpty {
                ContentUnavailableView("No Sessions", systemImage: "square.stack.3d.up.slash",
                                       description: Text("Run a drone or burst scan to find redundant photo sequences."))
            }
        }
    }
}

/// One session's headline: type, photo count, and best/redundant tallies.
private struct SessionRow: View {
    let cluster: SessionClusterRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(SessionDisplay.title(cluster.sessionType), systemImage: SessionDisplay.icon(cluster.sessionType))
                .font(.headline)
            Text("\(cluster.assetIdentifiers.count) photos · \(cluster.recommendedBestShotIds.count) best · \(cluster.suggestedRemovalIds.count) redundant")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

enum SessionDisplay {
    static func title(_ type: SessionType) -> String {
        switch type {
        case .burst: return "Burst"
        case .droneLike: return "Drone-like sequence"
        case .photoSession: return "Photo session"
        case .event: return "Event"
        }
    }

    static func icon(_ type: SessionType) -> String {
        switch type {
        case .burst: return "square.stack.3d.down.right"
        case .droneLike: return "airplane"
        case .photoSession: return "camera"
        case .event: return "calendar"
        }
    }
}

/// One session in detail: best shots, protected unique angles, and the redundant
/// photos (pre-selected for removal). Cleanup moves to Recently Deleted only;
/// unique angles and best shots are never auto-selected.
struct SessionClusterDetailView: View {
    let cluster: SessionClusterRecord

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var assetsByID: [String: PHAsset] = [:]
    @State private var removalSelection: Set<String> = []
    @State private var showConfirmation = false
    @State private var albumMessage: String?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                section("Best shots", ids: cluster.recommendedBestShotIds, role: .best)
                section("Protected unique angles", ids: cluster.protectedUniqueShotIds, role: .protected)
                section("Redundant", ids: cluster.suggestedRemovalIds, role: .redundant)
            }
            .padding()
        }
        .navigationTitle(SessionDisplay.title(cluster.sessionType))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(isPresented: $showConfirmation) {
            CleanupConfirmationView(count: removalSelection.count) { await performCleanup() }
                .presentationDetents([.medium])
        }
        .task {
            let resolved = AssetResolver.assets(for: cluster.assetIdentifiers)
            assetsByID = Dictionary(uniqueKeysWithValues: resolved.map { ($0.localIdentifier, $0) })
            removalSelection = Set(cluster.suggestedRemovalIds)
        }
    }

    enum Role { case best, protected, redundant }

    @ViewBuilder
    private func section(_ title: String, ids: [String], role: Role) -> some View {
        if !ids.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(ids, id: \.self) { id in
                        if let asset = assetsByID[id] {
                            SessionCell(
                                asset: asset,
                                role: role,
                                isMarkedForRemoval: role == .redundant && removalSelection.contains(id)
                            )
                            .onTapGesture {
                                guard role == .redundant else { return }
                                if removalSelection.contains(id) { removalSelection.remove(id) }
                                else { removalSelection.insert(id) }
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        VStack(spacing: 8) {
            if let albumMessage {
                Text(albumMessage).font(.caption).foregroundStyle(.secondary)
            }
            Button {
                Task { await createAlbum() }
            } label: {
                Label("Create Best Shots Album", systemImage: "rectangle.stack.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(cluster.recommendedBestShotIds.isEmpty)

            Button(role: .destructive) {
                showConfirmation = true
            } label: {
                Text(removalSelection.isEmpty ? "Select photos to remove" : "Move \(removalSelection.count) to Recently Deleted")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(removalSelection.isEmpty)
        }
        .padding()
        .background(.bar)
    }

    private func createAlbum() async {
        let name = "CleanShots Picks"
        let result = await AlbumCreationService().createAlbum(named: name, assetIdentifiers: cluster.recommendedBestShotIds)
        switch result {
        case .success(let count): albumMessage = "Added \(count) to \"\(name)\"."
        case .empty: albumMessage = "No best shots to add."
        case .failed(let message): albumMessage = message
        }
    }

    private func performCleanup() async -> PhotoMutationService.Result {
        let result = await PhotoMutationService().moveToRecentlyDeleted(Array(removalSelection))
        if result == .success {
            modelContext.delete(cluster)
            try? modelContext.save()
            dismiss()
        }
        return result
    }
}

private struct SessionCell: View {
    let asset: PHAsset
    let role: SessionClusterDetailView.Role
    let isMarkedForRemoval: Bool

    var body: some View {
        AssetThumbnailView(asset: asset, targetSize: CGSize(width: 220, height: 220))
            .aspectRatio(1, contentMode: .fill)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: 3) }
            .overlay(alignment: .topLeading) { badge }
            .opacity(isMarkedForRemoval ? 0.55 : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityAddTraits(role == .redundant ? .isButton : [])
            .accessibilityAddTraits(isMarkedForRemoval ? [.isSelected] : [])
    }

    private var accessibilityLabel: String {
        switch role {
        case .best: return "Best shot, kept"
        case .protected: return "Protected unique angle, kept"
        case .redundant: return "Redundant photo, " + (isMarkedForRemoval ? "selected for removal" : "not selected")
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch role {
        case .best:
            icon("star.fill", .green)
        case .protected:
            icon("lock.fill", .orange)
        case .redundant:
            icon(isMarkedForRemoval ? "minus.circle.fill" : "circle", isMarkedForRemoval ? .red : .secondary)
        }
    }

    private func icon(_ name: String, _ color: Color) -> some View {
        Image(systemName: name)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .padding(6)
    }

    private var borderColor: Color {
        switch role {
        case .best: return .green
        case .protected: return .orange
        case .redundant: return isMarkedForRemoval ? .red : .clear
        }
    }
}
