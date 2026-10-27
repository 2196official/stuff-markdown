//
//  Document.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

extension StuffMarkdown {
    /// A Stuff Markdown document: an optional version marker and title, then its items grouped into sections.
    ///
    /// Parsing any text gives a document, and writing a document gives Stuff Markdown, so a document read from canonical text writes that same text back.
    public struct Document: Codable, Equatable, Hashable, Sendable {
        /// The version named by the `<!-- stuff-markdown: N -->` marker on the first line, or `nil` when there's no marker.
        public var version: Int?
    
        /// The `#` title, such as the List or view that was exported.
        public var title: Header?
    
        /// The document's items in order, grouped under `##` section headers or, without a header, by the blank lines between them.
        public var sections: [Section]
    
    
        /// Creates a document.
        public init(version: Int? = nil, title: Header? = nil, sections: [Section] = []) {
            self.version = version
            self.title = title
            self.sections = sections
        }
    
    
        /// Every item in the document, in order.
        public var items: [Item] {
            sections.flatMap(\.items)
        }
    }
    
    
    
    // MARK: - Section
    /// A run of items, under a `##` header or, without one, set apart from the items around it by a blank line.
    public struct Section: Codable, Equatable, Hashable, Sendable {
        /// The `##` header, or `nil` for a group of items without one.
        public var header: Header?
    
        /// The section's items in order.
        public var items: [Item]
    
    
        /// Creates a section.
        public init(header: Header? = nil, items: [Item] = []) {
            self.header = header
            self.items = items
        }
    }
    
    
    
    // MARK: - Header
    /// A `#` title or `##` section header, with the same details and notes an item can carry.
    public struct Header: Codable, Equatable, Hashable, Sendable {
        /// The header's name, unescaped.
        public var name: String
    
        /// The details written after the name.
        public var details: Details
    
        /// The notes quoted on the lines below the header.
        public var notes: String?
    
    
        /// Creates a header.
        public init(name: String, details: Details = Details(), notes: String? = nil) {
            self.name = name
            self.details = details
            self.notes = notes
        }
    
    
        private enum CodingKeys: String, CodingKey {
            case name
            case notes
        }
    
    
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = try container.decode(String.self, forKey: .name)
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
            details = try Details(from: decoder)
        }
    
    
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try details.encode(to: encoder)
            try container.encodeIfPresent(notes, forKey: .notes)
        }
    }
    
    
    
    // MARK: - Item
    /// One item line: a Task, List, Heading, or Space.
    public struct Item: Codable, Equatable, Hashable, Sendable {
        /// The checkbox status, or `nil` for a line with no checkbox, which is how a Space is written.
        public var status: Status?
    
        /// The item's name, unescaped.
        public var name: String
    
        /// The details written after the name.
        public var details: Details
    
        /// The notes quoted on the lines below the item.
        public var notes: String?
    
    
        /// Creates an item.
        public init(status: Status?, name: String, details: Details = Details(), notes: String? = nil) {
            self.status = status
            self.name = name
            self.details = details
            self.notes = notes
        }
    
    
        private enum CodingKeys: String, CodingKey {
            case status
            case name
            case notes
        }
    
    
        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decodeIfPresent(Status.self, forKey: .status)
            name = try container.decode(String.self, forKey: .name)
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
            details = try Details(from: decoder)
        }
    
    
        public func encode(to encoder: any Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encodeIfPresent(status, forKey: .status)
            try container.encode(name, forKey: .name)
            try details.encode(to: encoder)
            try container.encodeIfPresent(notes, forKey: .notes)
        }
    }
    
    
    
    // MARK: - Status
    /// An item's checkbox.
    public enum Status: String, Codable, CaseIterable, Hashable, Sendable {
        /// `- [ ]`
        case available
        /// `- [x]`, also read from `- [X]`.
        case complete
        /// `- [/]`
        case cancelled
        /// `- [~]`
        case inProgress
    
    
        /// The character between the checkbox's brackets.
        public var checkboxCharacter: Character {
            switch self {
            case .available: " "
            case .complete: "x"
            case .cancelled: "/"
            case .inProgress: "~"
            }
        }
    
    
        /// The status written by a checkbox character, or `nil` when the character isn't one Stuff Markdown uses.
        public init?(checkboxCharacter: Character) {
            switch checkboxCharacter {
            case " ": self = .available
            case "x", "X": self = .complete
            case "/": self = .cancelled
            case "~": self = .inProgress
            default: return nil
            }
        }
    }
}
