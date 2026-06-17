import Foundation

/// Why a photo is protected from deletion. Maps to the spec's hard protection rules.
enum ProtectionReason: String, Sendable, Equatable, CaseIterable {
    case favorite
    case edited
    case livePhoto
    case hidden
    case shared
    case hasPeople

    var explanation: String {
        switch self {
        case .favorite: return "it is a favorite"
        case .edited: return "it has edits"
        case .livePhoto: return "it is a Live Photo"
        case .hidden: return "it is hidden"
        case .shared: return "it is in a shared album"
        case .hasPeople: return "it contains people"
        }
    }
}

/// Which protections are active. Defaults to all on (safest); the user may turn
/// individual protections off via explicit action.
struct ProtectionPolicy: Sendable, Equatable {
    var protectFavorites = true
    var protectEdited = true
    var protectLivePhotos = true
    var protectHidden = true
    var protectShared = true
    var protectPeople = true

    static let `default` = ProtectionPolicy()
}

/// Pure evaluation of the hard protection rules. No PhotoKit dependency.
struct ProtectionPolicyEngine {
    let policy: ProtectionPolicy

    init(policy: ProtectionPolicy = .default) {
        self.policy = policy
    }

    func protectionReasons(for flags: PhotoFlags) -> [ProtectionReason] {
        var reasons: [ProtectionReason] = []
        if policy.protectFavorites, flags.isFavorite { reasons.append(.favorite) }
        if policy.protectEdited, flags.isEdited { reasons.append(.edited) }
        if policy.protectLivePhotos, flags.isLivePhoto { reasons.append(.livePhoto) }
        if policy.protectHidden, flags.isHidden { reasons.append(.hidden) }
        if policy.protectShared, flags.isShared { reasons.append(.shared) }
        if policy.protectPeople, flags.personDetected { reasons.append(.hasPeople) }
        return reasons
    }

    func isProtected(_ flags: PhotoFlags) -> Bool {
        !protectionReasons(for: flags).isEmpty
    }
}
