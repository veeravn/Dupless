import Photos

/// Describes which assets a scan should consider. MVP 1 supports recent, album,
/// and date-range scopes; later MVPs reuse the same type for Siri-driven scans.
enum ScanScope: Equatable, Hashable {
    case recent(limit: Int)
    case dateRange(start: Date, end: Date)
    case album(localIdentifier: String)

    var displayName: String {
        switch self {
        case .recent(let limit): return "Recent · \(limit) photos"
        case .dateRange: return "Date range"
        case .album: return "Album"
        }
    }

    /// Stable identity for a scan, used to find/resume its checkpoint.
    var signature: String {
        switch self {
        case .recent(let limit): return "recent:\(limit)"
        case .dateRange(let start, let end):
            return "date:\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
        case .album(let id): return "album:\(id)"
        }
    }
}

/// Options layered on top of a scope (mirrors ScanSetupView toggles).
struct ScanOptions: Equatable, Hashable {
    var includeScreenshots: Bool = true
    var excludeFavorites: Bool = true
    /// Optional subject/theme to narrow the scan to (e.g. "birthday"), applied by
    /// on-device content classification after the scope is fetched. Nil scans the
    /// whole scope. PhotoKit can't filter by content, so this is a post-fetch pass.
    var contentQuery: String?
    /// Optional place/landmark to narrow the scan to (e.g. "mall of america"),
    /// applied by reverse-geocoding each photo's location. Requires the opt-in
    /// location lookup (off by default); ignored otherwise.
    var locationQuery: String?

    static let `default` = ScanOptions()

    var signature: String { "scr:\(includeScreenshots)|fav:\(excludeFavorites)|q:\(contentQuery ?? "")|loc:\(locationQuery ?? "")" }
}

/// Fetches `PHAsset`s for a given scope. Pure PhotoKit; no image data loaded here.
struct PhotoAssetFetcher {

    func fetchAssets(scope: ScanScope, options: ScanOptions = .default) -> PHFetchResult<PHAsset> {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.includeHiddenAssets = false

        var predicates: [NSPredicate] = [
            // Images only for MVP 1; video dedupe is out of scope.
            NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        ]

        if options.excludeFavorites {
            predicates.append(NSPredicate(format: "favorite == NO"))
        }
        if !options.includeScreenshots {
            predicates.append(
                NSPredicate(
                    format: "NOT ((mediaSubtype & %d) != 0)",
                    PHAssetMediaSubtype.photoScreenshot.rawValue
                )
            )
        }

        switch scope {
        case .recent(let limit):
            fetchOptions.fetchLimit = limit
            fetchOptions.predicate = compound(predicates)
            return PHAsset.fetchAssets(with: fetchOptions)

        case .dateRange(let start, let end):
            predicates.append(
                NSPredicate(
                    format: "creationDate >= %@ AND creationDate <= %@",
                    start as NSDate, end as NSDate
                )
            )
            fetchOptions.predicate = compound(predicates)
            return PHAsset.fetchAssets(with: fetchOptions)

        case .album(let localIdentifier):
            fetchOptions.predicate = compound(predicates)
            let collections = PHAssetCollection.fetchAssetCollections(
                withLocalIdentifiers: [localIdentifier], options: nil
            )
            guard let collection = collections.firstObject else {
                return PHFetchResult<PHAsset>()
            }
            return PHAsset.fetchAssets(in: collection, options: fetchOptions)
        }
    }

    /// Lists user albums (non-empty) for the album-scope picker, with a photo
    /// count for display. Sorted by title.
    func userAlbums() -> [AlbumInfo] {
        let countOptions = PHFetchOptions()
        countOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let result = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        var albums: [AlbumInfo] = []
        result.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: countOptions).count
            guard count > 0 else { return }
            albums.append(
                AlbumInfo(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "Untitled Album",
                    photoCount: count
                )
            )
        }
        return albums.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func compound(_ predicates: [NSPredicate]) -> NSPredicate {
        NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }
}

/// Lightweight, display-ready album descriptor for the scan-scope picker.
struct AlbumInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let photoCount: Int
}
