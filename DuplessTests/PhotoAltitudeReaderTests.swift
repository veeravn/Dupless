import XCTest
import ImageIO
import UniformTypeIdentifiers
import UIKit
@testable import Dupless

final class PhotoAltitudeReaderTests: XCTestCase {
    /// Builds a tiny JPEG, optionally embedding a GPS altitude (ref 0 = above sea
    /// level, 1 = below), so the reader can be tested without PhotoKit.
    private func jpeg(altitude: Double?, ref: Int = 0) -> Data {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16)).image { ctx in
            UIColor.gray.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 16, height: 16))
        }
        let cg = image.cgImage!
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, UTType.jpeg.identifier as CFString, 1, nil)!
        var props: [CFString: Any] = [:]
        if let altitude {
            props[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSAltitude: altitude,
                kCGImagePropertyGPSAltitudeRef: ref,
            ] as [CFString: Any]
        }
        CGImageDestinationAddImage(dest, cg, props as CFDictionary)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    func testReadsAboveSeaLevelAltitude() throws {
        let data = jpeg(altitude: 120.5)
        let altitude = try XCTUnwrap(PhotoAltitudeReader.altitude(fromImageData: data))
        XCTAssertEqual(altitude, 120.5, accuracy: 0.5)
    }

    func testBelowSeaLevelAltitudeIsNegative() throws {
        let data = jpeg(altitude: 8.0, ref: 1)
        let altitude = try XCTUnwrap(PhotoAltitudeReader.altitude(fromImageData: data))
        XCTAssertLessThan(altitude, 0)
        XCTAssertEqual(altitude, -8.0, accuracy: 0.5)
    }

    func testNoGPSReturnsNil() {
        let data = jpeg(altitude: nil)
        XCTAssertNil(PhotoAltitudeReader.altitude(fromImageData: data), "Missing GPS altitude must be nil, not an error.")
    }

    func testGarbageDataReturnsNil() {
        XCTAssertNil(PhotoAltitudeReader.altitude(fromImageData: Data([0x00, 0x01, 0x02, 0x03])))
    }
}
