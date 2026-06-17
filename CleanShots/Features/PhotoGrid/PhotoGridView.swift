import Photos
import SwiftUI

/// A simple scrollable grid of recent photo thumbnails. Phase 1 deliverable —
/// later phases replace/augment this with grouped duplicate review.
struct PhotoGridView: View {
    @State private var model = PhotoGridModel()

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 2)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(model.assets, id: \.localIdentifier) { asset in
                    ThumbnailCell(asset: asset) { await model.thumbnail(for: asset) }
                }
            }
            .padding(2)
        }
        .navigationTitle("Recent Photos")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if model.assets.isEmpty {
                ContentUnavailableView("No Photos", systemImage: "photo.on.rectangle.angled")
            }
        }
        .task { model.load() }
    }
}

/// Loads its thumbnail asynchronously and caches via the loader behind the model.
private struct ThumbnailCell: View {
    let asset: PHAsset
    let load: () async -> UIImage?

    @State private var image: UIImage?

    var body: some View {
        Color(.secondarySystemBackground)
            .aspectRatio(1, contentMode: .fill)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .task(id: asset.localIdentifier) {
                image = await load()
            }
    }
}
