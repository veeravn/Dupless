import Foundation

/// Template (non-LLM) explanations for recommendations and protections, matching
/// the spec's phrasing. MVP 4 will optionally replace these with Foundation
/// Models output.
enum RecommendationText {
    /// "Recommended because it is the sharpest image and has the highest resolution."
    static func keeperSummary(badges: [QualityBadge]) -> String {
        // Each reason is a full predicate (verb included) so they read naturally
        // when joined, e.g. "is the sharpest image and has the highest resolution".
        var predicates: [String] = []
        if badges.contains(.sharpest) { predicates.append("is the sharpest image") }
        if badges.contains(.bestExposure) { predicates.append("has the best exposure") }
        if badges.contains(.highestResolution) { predicates.append("has the highest resolution") }
        if badges.contains(.hasPeople) { predicates.append("includes people") }
        if badges.contains(.favorite) { predicates.append("is a favorite") }
        if badges.contains(.edited) { predicates.append("is your edited version") }

        guard !predicates.isEmpty else { return "Recommended as the best of this group." }
        return "Recommended because it " + joined(predicates) + "."
    }

    /// "Protected because it is a favorite."
    static func protectionSummary(reasons: [ProtectionReason]) -> String? {
        guard !reasons.isEmpty else { return nil }
        return "Protected because " + joined(reasons.map(\.explanation)) + "."
    }

    /// "Suggested removal because it is visually similar and has more motion blur."
    static func removalSummary(badges: [QualityBadge]) -> String {
        var reasons = ["visually similar"]
        if badges.contains(.blurry) { reasons.append("has more motion blur") }
        else if badges.contains(.lowerResolution) { reasons.append("is lower resolution") }
        return "Suggested removal because it is " + joined(reasons) + "."
    }

    private static func joined(_ parts: [String]) -> String {
        switch parts.count {
        case 0: return ""
        case 1: return parts[0]
        case 2: return "\(parts[0]) and \(parts[1])"
        default:
            return parts.dropLast().joined(separator: ", ") + ", and " + parts[parts.count - 1]
        }
    }
}
