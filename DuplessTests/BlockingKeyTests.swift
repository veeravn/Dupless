import XCTest
@testable import Dupless

final class BlockingKeyTests: XCTestCase {
    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: iso)!
    }

    func testSameDaySameAspectSameKey() {
        let morning = date("2026-06-16T08:00:00Z")
        let evening = date("2026-06-16T20:00:00Z")
        let a = BlockingKey.make(creationDate: morning, pixelWidth: 4000, pixelHeight: 3000, isScreenshot: false)
        let b = BlockingKey.make(creationDate: evening, pixelWidth: 4000, pixelHeight: 3000, isScreenshot: false)
        XCTAssertEqual(a, b)
    }

    func testDifferentDaysDifferentKeys() {
        let day1 = BlockingKey.make(creationDate: date("2026-06-16T12:00:00Z"), pixelWidth: 4000, pixelHeight: 3000, isScreenshot: false)
        let day2 = BlockingKey.make(creationDate: date("2026-06-17T12:00:00Z"), pixelWidth: 4000, pixelHeight: 3000, isScreenshot: false)
        XCTAssertNotEqual(day1, day2)
    }

    func testDifferentAspectRatioDifferentKeys() {
        let landscape = BlockingKey.make(creationDate: date("2026-06-16T12:00:00Z"), pixelWidth: 4000, pixelHeight: 3000, isScreenshot: false)
        let portrait = BlockingKey.make(creationDate: date("2026-06-16T12:00:00Z"), pixelWidth: 3000, pixelHeight: 4000, isScreenshot: false)
        XCTAssertNotEqual(landscape, portrait)
    }

    func testScreenshotFlagSeparatesKeys() {
        let photo = BlockingKey.make(creationDate: date("2026-06-16T12:00:00Z"), pixelWidth: 1170, pixelHeight: 2532, isScreenshot: false)
        let shot = BlockingKey.make(creationDate: date("2026-06-16T12:00:00Z"), pixelWidth: 1170, pixelHeight: 2532, isScreenshot: true)
        XCTAssertNotEqual(photo, shot)
        XCTAssertTrue(shot.hasSuffix("s"))
        XCTAssertTrue(photo.hasSuffix("p"))
    }

    func testNilDateUsesNodateBucket() {
        let key = BlockingKey.make(creationDate: nil, pixelWidth: 100, pixelHeight: 100, isScreenshot: false)
        XCTAssertTrue(key.hasPrefix("nodate"))
    }

    func testZeroHeightDoesNotCrash() {
        let key = BlockingKey.make(creationDate: nil, pixelWidth: 100, pixelHeight: 0, isScreenshot: false)
        XCTAssertEqual(key, "nodate|0|p")
    }
}
