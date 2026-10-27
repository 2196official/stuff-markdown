//
//  DetailReader.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

import Foundation

extension StuffMarkdown {
    /// Reads Stuff Markdown details off the end of one item or header line, leaving the name behind.
    ///
    /// Details are read from the end backward, in any order, until the text no longer ends in one. Each must follow whitespace, so an escaped `\#`, `\*`, `\(`, or `\<` never reads as one. A `#Tag` matching none of the known Tags stays in the name, and anything before it can still be read.
    struct DetailReader {
        /// The text not yet read as details.
        private(set) var name: String
    
        /// The details read so far.
        private(set) var details = Details()
    
        /// The `tagKey` of every known Tag, or `nil` when every `#Tag` is read.
        private let knownTagKeys: Set<String>?
    
        /// Reads dates written before Stuff Markdown, when the app supports them.
        private let readsLegacyDay: (@Sendable (String) -> Day?)?
    
        /// Tags read so far, last first.
        private var tagsReadBackward: [String] = []
    
        /// Unknown `#Tag` words, last first, restored to the end of the name once reading finishes.
        private var keptWordsBackward: [String] = []
    
    
        /// Creates a reader for one line's text, without its marker.
        init(text: String, options: ParseOptions, knownTagKeys: Set<String>?) {
            self.name = text.trimmingCharacters(in: .whitespaces)
            self.knownTagKeys = knownTagKeys
            self.readsLegacyDay = options.readsLegacyDay
        }
    
    
        /// Reads details from the end of the line until none is left.
        mutating func read() {
            /// Every detail ends in a known character, so only the readers that could match the text's last character run, and a plain name runs none.
            while let lastCharacter = name.last {
                let didRead = switch lastCharacter {
                case ")": readRepeat() || readDependency() || readTag()
                case "*": readDeadline() || readPlan() || readSomeday() || readTag()
                case ">": readExtension() || readTag()
                default: readTag()
                }
                guard didRead else { break }
            }
    
            var seenTagKeys = Set<String>()
            details.tags = tagsReadBackward.reversed().filter { seenTagKeys.insert(StuffMarkdown.tagKey($0)).inserted }
    
            if !keptWordsBackward.isEmpty {
                name = ([name] + keptWordsBackward.reversed()).joined(separator: " ")
            }
        }
    
    
    
        // MARK: Readers
        /// Reads a repeat in Stuff Markdown's exact wording, such as `(repeats every week on Saturday)`.
        private mutating func readRepeat() -> Bool {
            guard details.repeat == nil,
                  let match = trailingMatch(Self.repeatRegex),
                  let description = match.groups.first else { return false }
            consume(match)
            details.repeat = description
            return true
        }
    
    
        /// Reads `(dependent on "Name")`.
        private mutating func readDependency() -> Bool {
            guard details.dependency == nil, let match = trailingMatch(Self.dependencyRegex) else { return false }
            consume(match)
            details.dependency = match.groups.first
            return true
        }
    
    
        /// Reads a `**Deadline: YYYY-MM-DD**`.
        private mutating func readDeadline() -> Bool {
            guard details.deadline == nil,
                  let match = trailingMatch(Self.deadlineRegex),
                  let value = match.groups.first,
                  let day = day(from: value) else { return false }
            consume(match)
            details.deadline = day
            return true
        }
    
    
        /// Reads a `*Plan: YYYY-MM-DD*` or `*Plan: YYYY-MM-DD HH:MM*`.
        private mutating func readPlan() -> Bool {
            guard details.plan == nil,
                  let match = trailingMatch(Self.planRegex),
                  let value = match.groups.first else { return false }
    
            let parts = value.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            guard (1...2).contains(parts.count), let day = day(from: parts[0]) else { return false }
            let time = parts.count == 2 ? Time(parts[1]) : nil
            guard parts.count == 1 || time != nil else { return false }
    
            consume(match)
            details.plan = .day(day, time: time)
            return true
        }
    
    
        /// Reads `*Someday*`.
        private mutating func readSomeday() -> Bool {
            guard details.plan == nil, let match = trailingMatch(Self.somedayRegex) else { return false }
            consume(match)
            details.plan = .someday
            return true
        }
    
    
        /// Reads a `#Tag`, keeping it in the name when Tags are limited to known ones and it matches none.
        private mutating func readTag() -> Bool {
            /// A Tag is the last word, so the regex only runs when that word starts with `#`.
            guard let lastSpace = name.lastIndex(where: \.isWhitespace),
                  name[name.index(after: lastSpace)...].first == "#",
                  let match = trailingMatch(Self.tagRegex),
                  let word = match.groups.first else { return false }
            consume(match)
    
            if let knownTagKeys, !knownTagKeys.contains(StuffMarkdown.tagKey(word)) {
                keptWordsBackward.append("#\(word)")
            } else {
                tagsReadBackward.append(word)
            }
            return true
        }
    
    
        /// Reads a `<!-- … -->` extension comment, keeping its contents.
        private mutating func readExtension() -> Bool {
            guard let match = trailingMatch(Self.extensionRegex), let contents = match.groups.first else { return false }
            consume(match)
            details.extensions.insert(contents.trimmingCharacters(in: .whitespaces), at: 0)
            return true
        }
    
    
        /// Reads a `YYYY-MM-DD` day, or a legacy date when the app reads those.
        private func day(from text: String) -> Day? {
            Day(text) ?? readsLegacyDay?(text)
        }
    
    
    
        // MARK: Matching
        /// A detail found at the end of the name: where it starts and its capture groups.
        private struct TrailingMatch {
            /// The detail's range in the name, from its first character to the end.
            let range: Range<String.Index>
    
            /// The detail's capture groups.
            let groups: [String]
        }
    
    
        /// Compiles a detail pattern once, anchored to the end of the name and preceded by whitespace so an escaped character never matches.
        private static func trailingRegex(_ pattern: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: #"(?<=\s)"# + pattern + #"\s*$"#)
        }
    
        /// A repeat in Stuff Markdown's exact wording, so "(repeats weekly)" from elsewhere stays in the name.
        private static let repeatRegex = trailingRegex(#"\((repeats (?:every .+|on \d{4}-\d{2}-\d{2}.*|(?:a|\d+) (?:day|week|month|year)s? after each one is completed))\)"#)
    
        /// A dependency, capturing the name it depends on.
        private static let dependencyRegex = trailingRegex(#"\(dependent on "(.+)"\)"#)
    
        /// A Deadline, capturing its date.
        private static let deadlineRegex = trailingRegex(#"\*\*Deadline: ([^*]+)\*\*"#)
    
        /// A Plan, capturing its date and optional time.
        private static let planRegex = trailingRegex(#"\*Plan: ([^*]+)\*"#)
    
        /// Someday.
        private static let somedayRegex = trailingRegex(#"\*Someday\*"#)
    
        /// A `#Tag` word.
        private static let tagRegex = trailingRegex(#"#(\S+)"#)
    
        /// An extension comment, capturing its contents.
        private static let extensionRegex = trailingRegex(#"<!--((?:(?!-->).)*)-->"#)
    
    
        /// Finds the regex's detail at the end of the name.
        private func trailingMatch(_ regex: NSRegularExpression) -> TrailingMatch? {
            guard let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
                  let range = Range(match.range, in: name) else { return nil }
    
            let groups = (1..<match.numberOfRanges).compactMap { index in
                Range(match.range(at: index), in: name).map { String(name[$0]) }
            }
            return TrailingMatch(range: range, groups: groups)
        }
    
    
        /// Removes a matched detail from the end of the name.
        private mutating func consume(_ match: TrailingMatch) {
            name = String(name[..<match.range.lowerBound]).trimmingCharacters(in: .whitespaces)
        }
    }
}
