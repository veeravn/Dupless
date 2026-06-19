import Foundation

/// Decides how much to throttle on-device analysis based on thermal state and Low
/// Power Mode, so a long scan doesn't overheat the device or drain the battery
/// (the spec's thermal/battery awareness). Pure and testable — the scan engine
/// reads the live `ProcessInfo` values and passes them in.
enum ThermalPolicy {
    /// Delay to insert between analyzed photos for the given conditions.
    static func throttleDelay(thermalState: ProcessInfo.ThermalState, lowPowerMode: Bool) -> Duration {
        switch thermalState {
        case .critical:
            return .milliseconds(400)
        case .serious:
            return .milliseconds(150)
        case .fair:
            return lowPowerMode ? .milliseconds(80) : .zero
        case .nominal:
            return lowPowerMode ? .milliseconds(50) : .zero
        @unknown default:
            return .zero
        }
    }

    static func shouldThrottle(thermalState: ProcessInfo.ThermalState, lowPowerMode: Bool) -> Bool {
        throttleDelay(thermalState: thermalState, lowPowerMode: lowPowerMode) > .zero
    }
}
