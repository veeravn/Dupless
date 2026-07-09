import SwiftUI
import Photos

/// Lets the user choose scan scope + options before starting (ScanSetupView in
/// the spec). Defaults: Balanced sensitivity, protect favorites, manual review.
struct ScanSetupView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case album = "Album"
        case dateRange = "Date range"
        var id: String { rawValue }
    }

    @State private var scope: Scope = .recent
    @State private var recentLimit = 300
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: .now) ?? .now
    @State private var endDate = Date.now

    @State private var albums: [AlbumInfo] = []
    @State private var selectedAlbumID: String?
    @State private var isLoadingAlbums = false

    @State private var includeScreenshots = true
    @State private var excludeFavorites = true
    @AppStorage(AppSettings.protectLivePhotosKey) private var protectLivePhotos = true
    @State private var sensitivity: SimilaritySensitivity = AppSettings.defaultSensitivity

    @State private var startScan = false

    private let fetcher = PhotoAssetFetcher()

    var body: some View {
        Form {
            Section("Scope") {
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
                case .dateRange:
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }
            }

            Section {
                Toggle("Include screenshots", isOn: $includeScreenshots)
                Toggle("Protect favorites", isOn: $excludeFavorites)
                Toggle("Protect Live Photos", isOn: $protectLivePhotos)
            } header: {
                Text("Options")
            } footer: {
                Text("Protected Live Photos are grouped but never pre-selected for removal. Turn off to allow cleaning up duplicate Live Photos.")
            }

            Section {
                // Label hidden: the section header already says "Similarity".
                // An inline picker otherwise renders its label as a leading,
                // non-selectable row above the choices.
                Picker("Similarity", selection: $sensitivity) {
                    ForEach(SimilaritySensitivity.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("Similarity")
            } footer: {
                Text(sensitivity.subtitle)
            }
        }
        .navigationTitle("Scan Photos")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                BottomBannerAd()
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
            }
            .background(.bar)
        }
        .task(id: scope) {
            if scope == .album { await loadAlbums() }
        }
        .navigationDestination(isPresented: $startScan) {
            ScanProgressView(
                job: .fresh(
                    scope: resolvedScope,
                    options: ScanOptions(includeScreenshots: includeScreenshots, excludeFavorites: excludeFavorites),
                    sensitivity: sensitivity
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
        case .dateRange:
            return .dateRange(start: startDate, end: endDate)
        }
    }
}
