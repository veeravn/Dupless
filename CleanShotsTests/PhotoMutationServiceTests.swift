import XCTest
@testable import AI_Photo_Optimizer

final class PhotoMutationServiceTests: XCTestCase {
    /// Deleting nothing is a no-op success — guards the cleanup flow against
    /// empty selections without touching the Photos library.
    func testEmptySelectionSucceedsWithoutMutation() async {
        let result = await PhotoMutationService().moveToRecentlyDeleted([])
        XCTAssertEqual(result, .success)
    }

    /// Unknown identifiers resolve to zero assets → success, no mutation.
    func testUnknownIdentifiersSucceedWithoutMutation() async {
        let result = await PhotoMutationService().moveToRecentlyDeleted(["does-not-exist/L0/001"])
        XCTAssertEqual(result, .success)
    }
}
