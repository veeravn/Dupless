import Foundation

/// A relative date phrase the model may classify a request into. The model only
/// picks the phrase; the calendar math lives in `DatePhraseResolver` so it's
/// deterministic and unit-testable (the model never does date arithmetic).
enum DatePhrase: String, CaseIterable, Sendable {
    case today
    case yesterday
    case lastWeekend = "last_weekend"
    case lastWeek = "last_week"
    case lastMonth = "last_month"
    case lastYear = "last_year"

    /// A short spoken form for the resolved-settings summary.
    var spokenName: String {
        switch self {
        case .today: return "today"
        case .yesterday: return "yesterday"
        case .lastWeekend: return "last weekend"
        case .lastWeek: return "last week"
        case .lastMonth: return "last month"
        case .lastYear: return "last year"
        }
    }
}

/// Converts a `DatePhrase` into a concrete half-open date range `[start, end)`.
/// Pure and deterministic — inject `now`/`calendar` in tests. Week math treats a
/// week as Monday–Sunday regardless of locale so "last weekend" is always the
/// trailing Saturday + Sunday.
struct DatePhraseResolver {
    var calendar: Calendar
    var now: Date

    init(calendar: Calendar = .current, now: Date = .now) {
        self.calendar = calendar
        self.now = now
    }

    func resolve(_ phrase: DatePhrase) -> (start: Date, end: Date) {
        switch phrase {
        case .today:
            return (startOfToday, now)
        case .yesterday:
            return (day(offset: -1), startOfToday)
        case .lastWeekend:
            let monday = startOfThisWeek
            return (addDays(-2, to: monday), monday) // Sat 00:00 ..< Mon 00:00
        case .lastWeek:
            let monday = startOfThisWeek
            return (addDays(-7, to: monday), monday)
        case .lastMonth:
            let startThis = startOfMonth(now)
            return (calendar.date(byAdding: .month, value: -1, to: startThis)!, startThis)
        case .lastYear:
            let startThis = startOfYear(now)
            return (calendar.date(byAdding: .year, value: -1, to: startThis)!, startThis)
        }
    }

    // MARK: - Helpers

    private var startOfToday: Date { calendar.startOfDay(for: now) }

    private func day(offset: Int) -> Date { addDays(offset, to: startOfToday) }

    private func addDays(_ days: Int, to date: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: date)!
    }

    /// Monday 00:00 of the current week, computed from the weekday so it doesn't
    /// depend on `calendar.firstWeekday`.
    private var startOfThisWeek: Date {
        let weekday = calendar.component(.weekday, from: now) // Sun=1 ... Sat=7
        let daysSinceMonday = (weekday + 5) % 7               // Mon=0, ... Sun=6
        return addDays(-daysSinceMonday, to: startOfToday)
    }

    private func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }

    private func startOfYear(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year], from: date))!
    }
}
