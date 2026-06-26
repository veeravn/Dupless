import XCTest
@testable import Dupless

final class UnionFindTests: XCTestCase {
    func testDistinctElementsAreSeparate() {
        var uf = UnionFind(count: 4)
        XCTAssertNotEqual(uf.find(0), uf.find(1))
        XCTAssertNotEqual(uf.find(2), uf.find(3))
    }

    func testUnionMergesComponents() {
        var uf = UnionFind(count: 4)
        uf.union(0, 1)
        uf.union(1, 2)
        XCTAssertEqual(uf.find(0), uf.find(2))
        XCTAssertNotEqual(uf.find(0), uf.find(3))
    }

    func testTransitiveConnectivity() {
        var uf = UnionFind(count: 5)
        uf.union(0, 1)
        uf.union(2, 3)
        uf.union(1, 3) // bridges the two pairs
        let root = uf.find(0)
        for i in 1...3 { XCTAssertEqual(uf.find(i), root) }
        XCTAssertNotEqual(uf.find(4), root)
    }

    func testUnionIsIdempotent() {
        var uf = UnionFind(count: 3)
        uf.union(0, 1)
        uf.union(0, 1)
        uf.union(1, 0)
        XCTAssertEqual(uf.find(0), uf.find(1))
        XCTAssertNotEqual(uf.find(0), uf.find(2))
    }
}
