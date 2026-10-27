//
//  StuffMarkdown.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

import Foundation

/// Reads and writes Stuff Markdown, the plain-text format for Tasks specified in SPEC.md and at https://www.themitycompany.com/docs/stuff-markdown.
///
/// `parse(_:options:)` turns any text into a `Document`, and `write(_:)` turns a `Document` back into Stuff Markdown. Both follow the shared test suite in this package's `suite/cases` folder, which every Stuff Markdown implementation checks against.
public enum StuffMarkdown {
    /// The version of Stuff Markdown this package reads and writes.
    public static let version = 1

    /// The comment that opens a full document, naming its version. Markdown apps hide it.
    public static var versionMarker: String {
        versionMarker(for: version)
    }


    /// The version marker comment for the given version.
    public static func versionMarker(for version: Int) -> String {
        "<!-- stuff-markdown: \(version) -->"
    }


    /// A Tag name the way `#Tag` details are matched: without spaces and ignoring capitalization, so "Deep Work" and `#deepwork` match.
    public static func tagKey(_ name: some StringProtocol) -> String {
        String(name).replacingOccurrences(of: " ", with: "").lowercased()
    }
}



// MARK: - ParseOptions
extension StuffMarkdown {
    /// Choices an app makes about what it can import while parsing.
    public struct ParseOptions: Sendable {
        /// The Tags the app has, or `nil` to read every `#Tag`. When set, a `#Tag` matching none of them (by `StuffMarkdown.tagKey(_:)`) stays at the end of the name.
        public var knownTags: [String]?
    
        /// Reads a date in a format from before Stuff Markdown, such as the region-formatted `10/24/26` older Stuff exports wrote, when it isn't `YYYY-MM-DD`.
        public var readsLegacyDay: (@Sendable (String) -> Day?)?
    
    
        /// Creates parse options.
        public init(knownTags: [String]? = nil, readsLegacyDay: (@Sendable (String) -> Day?)? = nil) {
            self.knownTags = knownTags
            self.readsLegacyDay = readsLegacyDay
        }
    }
}
