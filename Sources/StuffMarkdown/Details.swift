//
//  Details.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

extension StuffMarkdown {
    /// The details written after an item's or header's name, always in this order: dependency, Plan or Someday, Deadline, Tags, repeat, then extensions.
    public struct Details: Codable, Equatable, Hashable, Sendable {
        /// The name of the item this one depends on, from `(dependent on "Name")`.
        public var dependency: String?
    
        /// The Plan, from `*Plan: YYYY-MM-DD*`, `*Plan: YYYY-MM-DD HH:MM*`, or `*Someday*`.
        public var plan: Plan?
    
        /// The Deadline, from `**Deadline: YYYY-MM-DD**`.
        public var deadline: Day?
    
        /// The Tags as written, without their `#`, from `#Tag` words.
        public var tags: [String]
    
        /// The repeat's description without its parentheses, such as "repeats every week on Saturday".
        public var `repeat`: String?
    
        /// The contents of trailing `<!-- … -->` comments, which hold details a later version adds. Readers that don't understand one keep it here rather than in the name.
        public var extensions: [String]
    
    
        /// Creates a set of details.
        public init(dependency: String? = nil,
                    plan: Plan? = nil,
                    deadline: Day? = nil,
                    tags: [String] = [],
                    repeat: String? = nil,
                    extensions: [String] = []) {
            self.dependency = dependency
            self.plan = plan
            self.deadline = deadline
            self.tags = tags
            self.repeat = `repeat`
            self.extensions = extensions
        }
    
    
        /// Whether there are no details.
        public var isEmpty: Bool {
            self == Details()
        }
    
    
        private enum CodingKeys: String, CodingKey {
            case dependency
            case plan
            case deadline
            case tags
            case `repeat`
            case extensions
        }
    
    
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            dependency = try container.decodeIfPresent(String.self, forKey: .dependency)
            plan = try container.decodeIfPresent(Plan.self, forKey: .plan)
            deadline = try container.decodeIfPresent(Day.self, forKey: .deadline)
            tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
            self.repeat = try container.decodeIfPresent(String.self, forKey: .repeat)
            extensions = try container.decodeIfPresent([String].self, forKey: .extensions) ?? []
        }
    
    
        /// Writes only the details that are present, so JSON stays as small as the Markdown it came from.
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(dependency, forKey: .dependency)
            try container.encodeIfPresent(plan, forKey: .plan)
            try container.encodeIfPresent(deadline, forKey: .deadline)
            if !tags.isEmpty {
                try container.encode(tags, forKey: .tags)
            }
            try container.encodeIfPresent(self.repeat, forKey: .repeat)
            if !extensions.isEmpty {
                try container.encode(extensions, forKey: .extensions)
            }
        }
    }
    
    
    
    // MARK: - Plan
    /// When an item is planned: a day with an optional reminder time, or Someday.
    public enum Plan: Codable, Equatable, Hashable, Sendable {
        /// `*Plan: YYYY-MM-DD*`, or `*Plan: YYYY-MM-DD HH:MM*` with a reminder.
        case day(Day, time: Time? = nil)
        /// `*Someday*`
        case someday
    
    
        /// The text inside the Plan's asterisks, such as "Plan: 2026-10-24 09:00" or "Someday".
        var markdownLabel: String {
            switch self {
            case .day(let day, let time):
                if let time {
                    return "Plan: \(day) \(time)"
                }
                return "Plan: \(day)"
            case .someday:
                return "Someday"
            }
        }
    
    
        /// In JSON a Plan is one string: "someday", "YYYY-MM-DD", or "YYYY-MM-DD HH:MM".
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            let text = try container.decode(String.self)
            if text == "someday" {
                self = .someday
                return
            }
    
            let parts = text.split(separator: " ").map(String.init)
            guard (1...2).contains(parts.count), let day = Day(parts[0]) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected \"someday\", \"YYYY-MM-DD\", or \"YYYY-MM-DD HH:MM\".")
            }
            guard parts.count == 2 else {
                self = .day(day)
                return
            }
            guard let time = Time(parts[1]) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a time as HH:MM.")
            }
            self = .day(day, time: time)
        }
    
    
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .day(let day, let time):
                try container.encode(time.map { "\(day) \($0)" } ?? day.description)
            case .someday:
                try container.encode("someday")
            }
        }
    }
    
    
    
    // MARK: - Day
    /// A calendar day with no time zone, written `YYYY-MM-DD`.
    public struct Day: Codable, Comparable, CustomStringConvertible, Hashable, Sendable {
        /// The year, from 1 through 9999.
        public let year: Int
    
        /// The month, from 1 through 12.
        public let month: Int
    
        /// The day of the month, from 1 through the month's length.
        public let day: Int
    
    
        /// Creates a day, or `nil` when it doesn't exist on the Gregorian calendar, such as February 30th.
        public init?(year: Int, month: Int, day: Int) {
            guard (1...9999).contains(year),
                  (1...12).contains(month),
                  (1...Self.length(ofMonth: month, inYear: year)).contains(day) else { return nil }
            self.year = year
            self.month = month
            self.day = day
        }
    
    
        /// Reads a day written exactly as `YYYY-MM-DD`, or `nil` when the text isn't one or names a day that doesn't exist.
        public init?(_ text: some StringProtocol) {
            let characters = Array(text)
            guard characters.count == 10, characters[4] == "-", characters[7] == "-",
                  let year = Self.number(characters[0..<4]),
                  let month = Self.number(characters[5..<7]),
                  let day = Self.number(characters[8..<10]) else { return nil }
            self.init(year: year, month: month, day: day)
        }
    
    
        /// `YYYY-MM-DD`.
        public var description: String {
            Self.padded(year, to: 4) + "-" + Self.padded(month, to: 2) + "-" + Self.padded(day, to: 2)
        }
    
    
        public static func < (lhs: Day, rhs: Day) -> Bool {
            (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
        }
    
    
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard let day = Day(try container.decode(String.self)) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a real day as YYYY-MM-DD.")
            }
            self = day
        }
    
    
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }
    
    
        /// The number of days in a month of the Gregorian calendar.
        private static func length(ofMonth month: Int, inYear year: Int) -> Int {
            switch month {
            case 2:
                let isLeapYear = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
                return isLeapYear ? 29 : 28
            case 4, 6, 9, 11:
                return 30
            default:
                return 31
            }
        }
    
    
        /// Reads ASCII digits as a number, or `nil` when any character isn't one.
        static func number(_ characters: ArraySlice<Character>) -> Int? {
            var value = 0
            for character in characters {
                guard character.isASCII, let digit = character.wholeNumberValue else { return nil }
                value = value * 10 + digit
            }
            return value
        }
    
    
        /// Writes a number with leading zeros up to the given width.
        static func padded(_ value: Int, to width: Int) -> String {
            let digits = String(value)
            return String(repeating: "0", count: max(0, width - digits.count)) + digits
        }
    }
    
    
    
    // MARK: - Time
    /// A 24-hour time of day with no time zone, written `HH:MM`.
    public struct Time: Codable, Comparable, CustomStringConvertible, Hashable, Sendable {
        /// The hour, from 0 through 23.
        public let hour: Int
    
        /// The minute, from 0 through 59.
        public let minute: Int
    
    
        /// Creates a time, or `nil` when the hour or minute is out of range.
        public init?(hour: Int, minute: Int) {
            guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
            self.hour = hour
            self.minute = minute
        }
    
    
        /// Reads a time written exactly as `HH:MM`, or `nil` when the text isn't one.
        public init?(_ text: some StringProtocol) {
            let characters = Array(text)
            guard characters.count == 5, characters[2] == ":",
                  let hour = Day.number(characters[0..<2]),
                  let minute = Day.number(characters[3..<5]) else { return nil }
            self.init(hour: hour, minute: minute)
        }
    
    
        /// `HH:MM`.
        public var description: String {
            Day.padded(hour, to: 2) + ":" + Day.padded(minute, to: 2)
        }
    
    
        public static func < (lhs: Time, rhs: Time) -> Bool {
            (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
        }
    
    
        public init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            guard let time = Time(try container.decode(String.self)) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected a time as HH:MM.")
            }
            self = time
        }
    
    
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(description)
        }
    }
}
