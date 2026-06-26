import XCTest
@testable import CleanShots

/// The model tends to copy an example from its own guide (e.g. 'dog') into
/// `contentQuery` when the request names a place but no visual subject. That
/// phantom filter would zero out the scan before location matching runs.
/// `corroboratedContentQuery` only honors a subject the request actually contains.
final class ContentCorroborationTests: XCTestCase {
    private func corroborate(_ query: String?, _ text: String) -> String? {
        FoundationModelScanParser.corroboratedContentQuery(query, in: text)
    }

    func testEchoedExampleIsDropped() {
        // Real-world failure: "scan recent mall of america photos" came back with
        // contentQuery="dog", which matched nothing and produced 0 groups.
        XCTAssertNil(corroborate("dog", "scan recent mall of america photos"))
    }

    func testTypedSubjectIsKept() {
        XCTAssertEqual(corroborate("beach", "find my beach photos"), "beach")
        XCTAssertEqual(corroborate("birthday", "dedupe birthday party pics"), "birthday")
    }

    func testMatchIsCaseInsensitive() {
        XCTAssertEqual(corroborate("food", "my FOOD shots"), "food")
    }

    func testNilStaysNil() {
        XCTAssertNil(corroborate(nil, "dog photos"))
    }
}
