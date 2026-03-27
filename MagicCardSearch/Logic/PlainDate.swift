// From https://www.mickf.net/tech/date-with-no-time-operations-swift/.

import Foundation

/// A string that represents dates using their ISO 8601 representations.
///
/// `PlainDate` is a way to handle dates with no time — such as `2022-03-02` for March 2nd of 2022 — to
/// perform operations with convenience including adding days, dealing with ranges, etc.
///
/// ## Usage Overview
///
/// A plain date can be initiated from a string literal, and can be used to create ranges.
///
///     let plainDate: PlainDate = "2022-03-01"
///     let aWeekLater = plainDate.advanced(by: 7)
///     for day in march1st ..< aWeekLater {
///       print(day)
///     }
public struct PlainDate {
    // MARK: - Creating an instance

    /// Returns a date string initialized using their ISO 8601 representation.
    /// - Parameters:
    ///   - dateAsString: The ISO 8601 representation of the date. For instance, `2022-03-02`for March 2nd of 2022.
    ///   - calendar: The calendar — including the time zone — to use. The default is the current calendar.
    /// - Returns: A date string, or `nil` if a valid date could not be created from `dateAsString`.
    public init?(from dateAsString: String, calendar: Calendar = .current) {
        let formatter = Self.createFormatter(timeZone: calendar.timeZone)
        guard let date = formatter.date(from: dateAsString) else {
            return nil
        }

        self.init(date: date, calendar: calendar, formatter: formatter)
    }

    /// Returns a date string initialized using their ISO 8601 representation.
    /// - Parameters:
    ///   - date: The date to represent.
    ///   - calendar: The calendar — including the time zone — to use. The default is the current calendar.
    public init(date: Date, calendar: Calendar = .current) {
        self.init(date: date, calendar: calendar, formatter: Self.createFormatter(timeZone: calendar.timeZone))
    }

    private init(date: Date, calendar: Calendar = .current, formatter: ISO8601DateFormatter) {
        self.formatter = formatter
        self.date = date
        self.calendar = calendar
    }

    public func formatted(_ style: Date.FormatStyle.DateStyle = .abbreviated) -> String {
        date.formatted(date: style, time: .omitted)
    }

    // MARK: - Properties

    private let formatter: ISO8601DateFormatter
    private let date: Date
    private let calendar: Calendar

    private static func createFormatter(timeZone: TimeZone) -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        formatter.timeZone = timeZone
        return formatter
    }
}

extension PlainDate: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(from: value)!
    }
}

extension PlainDate: CustomStringConvertible {
    public var description: String {
        formatter.string(from: date)
    }
}

extension PlainDate: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(date)
        hasher.combine(calendar)
    }
}

extension PlainDate: Strideable {
    public func distance(to other: PlainDate) -> Int {
        let timeInterval = date.distance(to: other.date)
        return Int(round(timeInterval / 86400.0))
    }

    public func advanced(by value: Int) -> PlainDate {
        let newDate = calendar.date(byAdding: .day, value: value, to: date)!
        return PlainDate(date: newDate, calendar: calendar)
    }
}
