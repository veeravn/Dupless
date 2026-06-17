import AppIntents

/// An album the user can pick in Siri/Shortcuts when scoping a scan.
struct PhotoAlbumEntity: AppEntity {
    let id: String          // PHAssetCollection.localIdentifier
    let title: String
    let photoCount: Int

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Album")

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(photoCount) photos")
    }

    static let defaultQuery = PhotoAlbumQuery()
}

/// Supplies album entities to App Intents, including name matching for phrases.
struct PhotoAlbumQuery: EntityQuery, EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [PhotoAlbumEntity] {
        let wanted = Set(identifiers)
        return await allAlbums().filter { wanted.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [PhotoAlbumEntity] {
        await allAlbums().filter { $0.title.localizedCaseInsensitiveContains(string) }
    }

    func suggestedEntities() async throws -> [PhotoAlbumEntity] {
        await allAlbums()
    }

    private func allAlbums() async -> [PhotoAlbumEntity] {
        await MainActor.run {
            PhotoAssetFetcher().userAlbums().map {
                PhotoAlbumEntity(id: $0.id, title: $0.title, photoCount: $0.photoCount)
            }
        }
    }
}
