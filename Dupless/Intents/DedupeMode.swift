import AppIntents

/// Siri/Shortcuts-facing dedupe mode. Mirrors `SimilaritySensitivity` plus a
/// drone/burst mode that maps to a burst-style scan until MVP 5 lands.
enum DedupeModeAppEnum: String, AppEnum {
    case conservative
    case balanced
    case aggressive
    case droneBurst

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Cleanup Mode")

    static let caseDisplayRepresentations: [DedupeModeAppEnum: DisplayRepresentation] = [
        .conservative: "Conservative",
        .balanced: "Balanced",
        .aggressive: "Aggressive",
        .droneBurst: "Drone / Burst",
    ]

    /// Maps to the on-device similarity sensitivity. Drone/burst uses aggressive
    /// grouping for MVP 3.
    var sensitivity: SimilaritySensitivity {
        switch self {
        case .conservative: return .conservative
        case .balanced: return .balanced
        case .aggressive, .droneBurst: return .aggressive
        }
    }

    init(sensitivity: SimilaritySensitivity) {
        switch sensitivity {
        case .conservative: self = .conservative
        case .balanced: self = .balanced
        case .aggressive: self = .aggressive
        }
    }
}
