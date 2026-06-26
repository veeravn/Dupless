import XCTest
import Foundation
@testable import Dupless

final class ThermalPolicyTests: XCTestCase {
    func testNominalDoesNotThrottle() {
        XCTAssertEqual(ThermalPolicy.throttleDelay(thermalState: .nominal, lowPowerMode: false), .zero)
        XCTAssertFalse(ThermalPolicy.shouldThrottle(thermalState: .nominal, lowPowerMode: false))
    }

    func testLowPowerModeThrottlesEvenWhenCool() {
        XCTAssertGreaterThan(ThermalPolicy.throttleDelay(thermalState: .nominal, lowPowerMode: true), .zero)
        XCTAssertTrue(ThermalPolicy.shouldThrottle(thermalState: .fair, lowPowerMode: true))
    }

    func testHotterStatesThrottleMore() {
        let fair = ThermalPolicy.throttleDelay(thermalState: .fair, lowPowerMode: true)
        let serious = ThermalPolicy.throttleDelay(thermalState: .serious, lowPowerMode: false)
        let critical = ThermalPolicy.throttleDelay(thermalState: .critical, lowPowerMode: false)
        XCTAssertGreaterThan(serious, fair)
        XCTAssertGreaterThan(critical, serious)
    }

    func testSeriousAndCriticalAlwaysThrottle() {
        XCTAssertTrue(ThermalPolicy.shouldThrottle(thermalState: .serious, lowPowerMode: false))
        XCTAssertTrue(ThermalPolicy.shouldThrottle(thermalState: .critical, lowPowerMode: false))
    }
}
