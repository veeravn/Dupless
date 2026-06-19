import SwiftUI
import Photos

/// Lets the user choose scope and angle-protection before a drone/burst scan.
/// Drone/burst mode clusters photos into shooting sessions, then suggests the
/// best shot per redundant sequence while protecting meaningfully different
/// angles (the spec's #1 risk mitigation).
struct DroneBurstSetupView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case album = "Album"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .recent
    @State private var recentLimit = 300

    @State private var albums: [AlbumInfo] = []
    @State private var selectedAlbumID: String?
    @State private var isLoadingAlbums = false

    @State private var preserveUniqueAngles = true

    @State private var startScan = false

    var body: some View {
        Form {
            Section {
                Picker("Scan", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                switch scope {
                case .recent:
                    Picker("Photos", selection: $recentLimit) {
                        Text("100").tag(100)
                        Text("300").tag(300)
                        Text("1,000").tag(1000)
                        Text("5,000").tag(5000)
                    }
                case .album:
                    albumPicker
                }
            } header: {
                Text("Scope")
            } footer: {
                Text("CleanShots groups these photos into shooting sessions by time and location, then finds redundant sequences.")
            }

            Section {
                Toggle("Protect unique angles", isOn: $preserveUniqueAngles)
            } footer: {
                Text(preserveUniqueAngles
                     ? "Shots from a different altitude, vantage point, or framing are kept even inside a burst — only near-identical frames are suggested for cleanup."
                     : "Every session is treated as plain duplicates. Only the best shot of each sequence is kept; different angles may be suggested for removal.")
            }
        }
        .navigationTitle("Drone / Burst")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            Button {
                startScan = true
            } label: {
                Text("Start Scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!canStartScan)
            .padding()
            .background(.bar)
        }
        .task(id: scope) {
            if scope == .album { await loadAlbums() }
        }
        .navigationDestination(isPresented: $startScan) {
            ScanProgressView(
                job: .droneBurst(
                    scope: resolvedScope,
                    options: .default,
                    droneOptions: DroneBurstOptions(preserveUniqueAngles: preserveUniqueAngles)
                )
            )
        }
    }

    @ViewBuilder
    private var albumPicker: some View {
        if isLoadingAlbums {
            HStack {
                Text("Albums")
                Spacer()
                ProgressView()
            }
        } else if albums.isEmpty {
            Text("No albums with photos")
                .foregroundStyle(.secondary)
        } else {
            Picker("Album", selection: $selectedAlbumID) {
                Text("Choose…").tag(String?.none)
                ForEach(albums) { album in
                    Text("\(album.title) (\(album.photoCount))").tag(String?.some(album.id))
                }
            }
        }
    }

    private var canStartScan: Bool {
        scope != .album || selectedAlbumID != nil
    }

    private func loadAlbums() async {
        guard albums.isEmpty else { return }
        isLoadingAlbums = true
        let loaded = await Task.detached { PhotoAssetFetcher().userAlbums() }.value
        albums = loaded
        isLoadingAlbums = false
    }

    private var resolvedScope: ScanScope {
        switch scope {
        case .recent:
            return .recent(limit: recentLimit)
        case .album:
            return .album(localIdentifier: selectedAlbumID ?? "")
        }
    }
}
