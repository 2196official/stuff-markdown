//
//  Writer.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

import Foundation

extension StuffMarkdown {
    /// Where a name and its details are written, which decides how notes are quoted.
    public enum Placement: Sendable {
        /// On an item line, where notes are quoted and indented two spaces so they stay inside the item.
        case item
        /// On a `#` title or `##` section header, where notes are quoted without indentation.
        case header
    }


    /// Writes a document as Stuff Markdown.
    ///
    /// The version marker and title come first, then each section separated by a blank line. A section's header notes are followed by a blank line before its items, and a section with a header but no items is still written, as an empty Heading is in Stuff. A document read from canonical Stuff Markdown writes back the same text.
    public static func write(_ document: Document) -> String {
        var opening: [String] = []
        if let version = document.version {
            opening.append(versionMarker(for: version))
        }
        if let title = document.title {
            opening.append(write(title, level: 1))
        }

        let blocks: [String] = document.sections.compactMap { section in
            var lines = section.items.map(write)
            if let header = section.header {
                if header.notes?.isEmpty == false && !lines.isEmpty {
                    lines.insert("", at: 0)
                }
                lines.insert(write(header, level: 2), at: 0)
            }
            return lines.isEmpty ? nil : lines.joined(separator: "\n")
        }

        let openingBlock = opening.isEmpty ? [] : [opening.joined(separator: "\n")]
        return (openingBlock + blocks).joined(separator: "\n\n")
    }


    /// Writes one item: its marker, name, and details on one line, then its notes on the lines below.
    public static func write(_ item: Item) -> String {
        marker(for: item.status) + escapedName(item.name) + text(for: item.details, notes: item.notes, placement: .item)
    }


    /// Writes a header at the given level, such as 1 for a `#` title or 2 for a `##` section, with its notes below it.
    public static func write(_ header: Header, level: Int) -> String {
        String(repeating: "#", count: max(1, level)) + " " + escapedName(header.name) + text(for: header.details, notes: header.notes, placement: .header)
    }


    /// The marker that starts an item line: a checkbox for a status, or `- ` without one.
    public static func marker(for status: Status?) -> String {
        guard let status else { return "- " }
        return "- [\(status.checkboxCharacter)] "
    }


    /// Writes details and notes as they follow a name: each detail after a space, in Stuff Markdown's fixed order, then each note line quoted on its own line.
    public static func text(for details: Details, notes: String?, placement: Placement) -> String {
        var text = ""

        if let dependency = details.dependency {
            text += " (dependent on \"\(dependency)\")"
        }
        if let plan = details.plan {
            text += " *\(plan.markdownLabel)*"
        }
        if let deadline = details.deadline {
            text += " **Deadline: \(deadline)**"
        }
        for tag in details.tags {
            text += " #" + tag.replacingOccurrences(of: " ", with: "")
        }
        if let description = details.repeat {
            text += " (\(description))"
        }
        for contents in details.extensions {
            text += " <!-- \(contents) -->"
        }

        if let notes, !notes.isEmpty {
            let quote = placement == .item ? "  >" : ">"
            for line in notes.split(separator: "\n", omittingEmptySubsequences: false) {
                text += line.isEmpty ? "\n\(quote)" : "\n\(quote) \(line)"
            }
        }

        return text
    }



    // MARK: Escaping
    /// The characters a backslash escapes in a name.
    private static let escapableCharacters: Set<Character> = ["#", "*", "(", "<", "\\"]


    /// Returns a name with a backslash before anything that would otherwise read as a detail, so it stays part of the name.
    ///
    /// That covers a `#` starting a word (a Tag), any `*` (Plan, Someday, and Deadline), a `(` opening "(dependent on" or "(repeats", and a `<` opening a `<!--` comment. A backslash already in front of one of these is doubled, so it survives being read back.
    public static func escapedName(_ name: String) -> String {
        let characters = Array(name)
        var escaped = ""
        for (index, character) in characters.enumerated() {
            let previous: Character? = index > 0 ? characters[index - 1] : nil
            let next: Character? = index + 1 < characters.count ? characters[index + 1] : nil
            let rest = characters[index...]

            switch character {
            case "\\" where next.map(escapableCharacters.contains) == true:
                escaped += "\\\\"
            case "#" where previous == nil || previous?.isWhitespace == true:
                escaped += "\\#"
            case "*":
                escaped += "\\*"
            case "(" where rest.starts(with: "(dependent on \"") || rest.starts(with: "(repeats "):
                escaped += "\\("
            case "<" where rest.starts(with: "<!--"):
                escaped += "\\<"
            default:
                escaped.append(character)
            }
        }
        return escaped
    }


    /// Removes the backslash before a `#`, `*`, `(`, `<`, or `\` in a name, and the whitespace around it.
    public static func unescapedName(_ name: String) -> String {
        var unescaped = ""
        var isEscaping = false
        for character in name {
            if isEscaping {
                if !escapableCharacters.contains(character) {
                    unescaped.append("\\")
                }
                unescaped.append(character)
                isEscaping = false
            } else if character == "\\" {
                isEscaping = true
            } else {
                unescaped.append(character)
            }
        }
        if isEscaping {
            unescaped.append("\\")
        }
        return unescaped.trimmingCharacters(in: .whitespaces)
    }
}
