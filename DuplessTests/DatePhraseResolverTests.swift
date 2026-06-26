import XCTest
@testable import CleanShots

final class DatePhraseResolverTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Wednesday, 2026-06-17 15:30 UTC. The Monday of its week is 2026-06-15.
    private func resolver() -> DatePhraseResolver {
        DatePhraseResolver(calendar: cal, now: date(2026, 6, 17, 15, 30))
    }

    func testToday() {
        let r = resolver().resolve(.today)
        XCTAssertEqual(r.start, date(2026, 6, 17))
        XCTAssertEqual(r.end, date(2026, 6, 17, 15, 30))
    }

    func testYesterday() {
        let r = resolver().resolve(.yesterday)
        XCTAssertEqual(r.start, date(2026, 6, 16))
        XCTAssertEqual(r.end, date(2026, 6, 17))
    }

    func testLastWeekendIsTrailingSaturdayAndSunday() {
        let r = resolver().resolve(.lastWeekend)
        XCTAssertEqual(r.start, date(2026, 6, 13)) // Saturday
        XCTAssertEqual(r.end, date(2026, 6, 15))   // Monday (exclusive)
    }

    func testLastWeekIsPreviousMondayToThisMonday() {
        let r = resolver().resolve(.lastWeek)
        XCTAssertEqual(r.start, date(2026, 6, 8))
        XCTAssertEqual(r.end, date(2026, 6, 15))
    }

    func testLastMonth() {
        let r = resolver().resolve(.lastMonth)
        XCTAssertEqual(r.start, date(2026, 5, 1))
        XCTAssertEqual(r.end, date(2026, 6, 1))
    }

    func testLastYear() {
        let r = resolver().resolve(.lastYear)
        XCTAssertEqual(r.start, date(2025, 1, 1))
        XCTAssertEqual(r.end, date(2026, 1, 1))
    }

    func testAllRangesAreNonEmptyAndOrdered() {
        let r = resolver()
        for phrase in DatePhrase.allCases {
            let range = r.resolve(phrase)
            XCTAssertLessThan(range.start, range.end, "\(phrase) should be a forward range")
        }
    }
}
