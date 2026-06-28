import Foundation

/// Per-image quality metrics, all normalized 0...1. Computed from the thumbnail
/// during analysis and cached for ranking and resume.
struct QualityScores: Sendable, Equatable, Codable {
    /// Edge energy / Laplacian variance. Higher = sharper.
    var sharpness: Double
    /// Histogram balance. 1.0 = well exposed; lower = under/over-exposed or clipped.
    var exposure: Double
    /// Histogram spread / local contrast. Higher = more contrast.
    var contrast: Double
    /// Directional/low-clarity blur estimate. 0 = crisp, 1 = heavy motion blur.
    var motionBlur: Double
    /// Coarse RGB color histogram (64 bins, one byte each) of the thumbnail. Lets
    /// the grouper tell apart same-backdrop shots whose *subject* differs — e.g. a
    /// bust-level portrait in two different outfits, which the grayscale hash and
    /// the Vision feature print both under-weight. `nil` for records analyzed
    /// before this field existed (grouping then falls back to the visual signals
    /// only). Optional so the existing cache stays decodable without a schema
    /// migration.
    var colorSignature: Data? = nil

    static let unknown = QualityScores(sharpness: 0.5, exposure: 0.5, contrast: 0.5, motionBlur: 0.5)
}

/// PhotoKit-derived flags that drive protection and ranking. Captured during
/// analysis so ranking stays a pure function over cached data.
struct PhotoFlags: Sendable, Equatable, Codable {
    var isFavorite: Bool = false
    var isEdited: Bool = false
    var isLivePhoto: Bool = false
    var isHidden: Bool = false
    var isShared: Bool = false
    var faceCount: Int = 0
    var personDetected: Bool = false
    /// Archived Vision feature print per detected face (largest faces first).
    /// Lets the grouper check whether two photos show the *same people* — so
    /// different family groupings shot against one backdrop stay apart, which
    /// face *count* alone can't distinguish. Empty for faceless photos, on the
    /// Simulator, and for records cached before this field existed. Defaulted so
    /// the existing cache stays decodable without a schema migration.
    var faceprints: [Data] = []
    /// Version of the analysis pipeline that produced this record. Lets a scan
    /// re-analyze records made by an older pipeline instead of trusting stale
    /// cached data — e.g. face prints cropped from the old 256px thumbnail are
    /// useless for identity matching, so bumping `PhotoAnalyzer.analysisVersion`
    /// forces them to be recomputed at the new resolution. Defaults to 0 (the
    /// implicit version of every record cached before this field existed), so it's
    /// migration-free.
    var analysisVersion: Int = 0

    static let none = PhotoFlags()
}

/// A photo ready to be ranked within a group.
struct RankablePhoto: Sendable, Equatable {
    let id: String
    let pixelCount: Int
    let quality: QualityScores
    let flags: PhotoFlags
}

/// Badges surfaced in the review UI to explain quality and protection at a glance.
enum QualityBadge: String, Sendable, Equatable, CaseIterable {
    case sharpest = "Sharpest"
    case bestExposure = "Best exposure"
    case highestResolution = "Highest resolution"
    case edited = "Edited"
    case favorite = "Favorite"
    case livePhoto = "Live Photo"
    case hasPeople = "Has people"
    case blurry = "Blurry"
    case lowerResolution = "Lower resolution"
    case protected = "Protected"

    var systemImage: String {
        switch self {
        case .sharpest: return "wand.and.stars"
        case .bestExposure: return "sun.max"
        case .highestResolution: return "arrow.up.right.square"
        case .edited: return "slider.horizontal.3"
        case .favorite: return "heart.fill"
        case .livePhoto: return "livephoto"
        case .hasPeople: return "person.2.fill"
        case .blurry: return "drop.fill"
        case .lowerResolution: return "arrow.down.right.square"
        case .protected: return "lock.fill"
        }
    }

    /// True for badges that signal a downside (used to tint them differently).
    var isNegative: Bool { self == .blurry || self == .lowerResolution }
}
