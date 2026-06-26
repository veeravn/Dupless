import Foundation

/// Cheap, image-free metadata captured from a `PHAsset` during analysis. These
/// are in-memory PhotoKit properties (no file I/O, no decode), cached alongside
/// the hash/quality so drone/burst session clustering (MVP 5) can group by time,
/// location, and burst membership without re-touching PhotoKit.
struct PhotoMetadata: Sendable, Equatable, Codable {
    var creationDate: Date?
    var latitude: Double?
    var longitude: Double?
    /// PhotoKit burst group identifier, when the shot is part of a burst.
    var burstIdentifier: String?
    /// width / height; 0 when unknown.
    var aspectRatio: Double

    static let unknown = PhotoMetadata(
        creationDate: nil, latitude: nil, longitude: nil, burstIdentifier: nil, aspectRatio: 0
    )

    var hasLocation: Bool { latitude != nil && longitude != nil }
    var isBurst: Bool { burstIdentifier != nil }
}
