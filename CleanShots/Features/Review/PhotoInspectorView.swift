import Photos
import SwiftUI

/// Identifies which photo to open the inspector on (Identifiable for
/// `.fullScreenCover(item:)`).
struct InspectorTarget: Identifiable {
    let startID: String
    var id: String { startID }
}

/// Full-screen viewer for a duplicate group: a large, zoom/pan-able image with a
/// filmstrip to move between the group's photos, so the user can inspect closely
/// before deciding. The keep/remove toggle is bound to the review screen's
/// selection, so changes here apply when it's dismissed.
struct PhotoInspectorView: View {
    let identifiers: [String]
    let keeperID: String?
    @Binding var removalSelection: Set<String>
    @State private var currentID: String
    @State private var assetsByID: [String: PHAsset] = [:]

    @Environment(\.dismiss) private var dismiss

    init(identifiers: [String], keeperID: String?, removalSelection: Binding<Set<String>>, startID: String) {
        self.identifiers = identifiers
        self.keeperID = keeperID
        self._removalSelection = removalSelection
        self._currentID = State(initialValue: startID)
    }

    private var currentIndex: Int { identifiers.firstIndex(of: currentID) ?? 0 }
    private var isRemoving: Bool { removalSelection.contains(currentID) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer(minLength: 0)
                if let asset = assetsByID[currentID] {
                    InspectorImage(asset: asset)
                        .id(currentID) // reset zoom when the photo changes
                } else {
                    ProgressView().tint(.white)
                }
                Spacer(minLength: 0)

                controls
                filmstrip
            }
        }
        .task { resolveAssets() }
        .statusBarHidden()
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.white.opacity(0.15), in: Circle())
            }
            .accessibilityLabel("Close")

            Spacer()
            Text("\(currentIndex + 1) of \(identifiers.count)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()

            // Balance the close button so the counter stays centered.
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                if currentID == keeperID {
                    Label("Recommended keeper", systemImage: "star.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                if let date = assetsByID[currentID]?.creationDate {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Button {
                if isRemoving { removalSelection.remove(currentID) }
                else { removalSelection.insert(currentID) }
            } label: {
                Label(isRemoving ? "Keep this photo" : "Mark for Removal",
                      systemImage: isRemoving ? "arrow.uturn.backward" : "trash")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .tint(isRemoving ? .green : .red)
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private var filmstrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(identifiers, id: \.self) { id in
                        if let asset = assetsByID[id] {
                            AssetThumbnailView(asset: asset, targetSize: CGSize(width: 120, height: 120))
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(id == currentID ? Color.white : .clear, lineWidth: 2)
                                }
                                .overlay(alignment: .topTrailing) {
                                    if removalSelection.contains(id) {
                                        Image(systemName: "minus.circle.fill")
                                            .symbolRenderingMode(.palette)
                                            .foregroundStyle(.white, .red)
                                            .font(.caption2)
                                            .padding(2)
                                    }
                                }
                                .id(id)
                                .onTapGesture { withAnimation { currentID = id } }
                                .accessibilityLabel("Photo \((identifiers.firstIndex(of: id) ?? 0) + 1)")
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 72)
            .onChange(of: currentID) { _, id in
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(currentID, anchor: .center) }
        }
        .padding(.bottom, 8)
    }

    private func resolveAssets() {
        assetsByID = Dictionary(
            AssetResolver.assets(for: identifiers).map { ($0.localIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }
}

/// Loads and displays one inspector image, with a zoom/pan gesture once ready.
private struct InspectorImage: View {
    let asset: PHAsset
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                ZoomableImage(image: image)
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: asset.localIdentifier) {
            image = await PhotoImageLoader.shared.inspectorImage(for: asset)
        }
    }
}

/// An image with pinch-to-zoom, drag-to-pan (when zoomed), and double-tap zoom.
/// No horizontal paging here, so the pan gesture has nothing to conflict with.
private struct ZoomableImage: View {
    let image: UIImage

    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var pinch: CGFloat = 1
    @GestureState private var drag: CGSize = .zero

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale * pinch)
            .offset(x: offset.width + drag.width, y: offset.height + drag.height)
            .gesture(
                MagnificationGesture()
                    .updating($pinch) { value, state, _ in state = value }
                    .onEnded { value in
                        scale = min(max(scale * value, 1), 5)
                        if scale == 1 { offset = .zero }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .updating($drag) { value, state, _ in
                        if scale > 1 { state = value.translation }
                    }
                    .onEnded { value in
                        guard scale > 1 else { return }
                        offset.width += value.translation.width
                        offset.height += value.translation.height
                    }
            )
            .onTapGesture(count: 2) {
                withAnimation(.spring(duration: 0.25)) {
                    if scale > 1 { scale = 1; offset = .zero } else { scale = 2.5 }
                }
            }
            .animation(.interactiveSpring, value: scale)
    }
}
