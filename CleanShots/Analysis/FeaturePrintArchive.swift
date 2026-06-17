import Foundation
import Vision

/// Archives/unarchives Vision feature prints so they can be cached for resume.
/// `VNFeaturePrintObservation` conforms to `NSSecureCoding`.
enum FeaturePrintArchive {
    nonisolated static func archive(_ observation: VNFeaturePrintObservation) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
    }

    nonisolated static func unarchive(_ data: Data) -> VNFeaturePrintObservation? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data)
    }
}
