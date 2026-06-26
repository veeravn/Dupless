import Photos
import SwiftData
import SwiftUI

/// Lists the duplicate groups from the latest scan (DuplicateGroupListView).
struct DuplicateGroupListView: View {
    @Query(sort: \DuplicateGroupRecord.confidence, order: .reverse)
    private var groups: [DuplicateGroupRecord]

    var body: some View {
        List {
            if groups.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Duplicates",
                        systemImage: "checkmark.seal",
                        description: Text("Your last scan didn't find any similar photos.")
                    )
                }
            } else {
                Section {
                    LabeledContent("Groups", value: "\(groups.count)")
                    LabeledContent("Suggested cleanup", value: "\(totalRemovable) photos")
                }

                Section("Groups") {
                    ForEach(groups) { group in
                        NavigationLink {
                            DuplicateGroupDetailView(group: group)
                        } label: {
                            GroupRow(group: group)
                        }
                    }
                }
            }
        }
        .navigationTitle("Duplicates")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var totalRemovable: Int {
        groups.reduce(0) { $0 + $1.estimatedRemovableCount }
    }
}

private struct GroupRow: View {
    let group: DuplicateGroupRecord

    var body: some View {
        HStack(spacing: 12) {
            if let asset = keeperAsset {
                AssetThumbnailView(asset: asset, targetSize: CGSize(width: 120, height: 120))
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("\(group.memberIdentifiers.count) similar photos")
                    .font(.body)
                Text("~\(group.estimatedRemovableCount) removable · \(Int(group.confidence * 100))% match")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var keeperAsset: PHAsset? {
        let id = group.recommendedKeeperIdentifier ?? group.memberIdentifiers.first
        return id.flatMap { AssetResolver.asset(for: $0) }
    }
}
