//
//  Parser.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

import Foundation

extension StuffMarkdown {
    /// Matches one item line with a checkbox, capturing its checkbox character and its text.
    private static let checkboxLineRegex = try! NSRegularExpression(pattern: #"^[ \t]*- \[([ xX/~])\] (.*)$"#)

    /// Matches an item line with a checkbox on any line of a longer text.
    private static let checkboxLineAnywhereRegex = try! NSRegularExpression(pattern: #"^[ \t]*- \[[ xX/~]\] "#, options: .anchorsMatchLines)

    /// Matches a further checkbox partway through an item line's text, as in `- [ ] A - [ ] B`, capturing its checkbox character.
    private static let inlineCheckboxRegex = try! NSRegularExpression(pattern: #" - \[([ xX/~])\] "#)

    /// Matches an unindented item line without a checkbox, the way a Space is written, capturing its text.
    private static let plainItemLineRegex = try! NSRegularExpression(pattern: #"^- (.*)$"#)

    /// Matches a `#` to `######` header line, capturing its hashes and its text.
    private static let headerLineRegex = try! NSRegularExpression(pattern: #"^(#{1,6})[ \t]+(.*)$"#)

    /// Matches the version marker, capturing its version.
    private static let versionMarkerRegex = try! NSRegularExpression(pattern: #"^<!--[ \t]*stuff-markdown:[ \t]*(\d+)[ \t]*-->$"#)

    /// Matches the start of a Markdown structure line (a header, bullet, quote, comment, or numbered item), which never continues a wrapped item line.
    private static let structureLineRegex = try! NSRegularExpression(pattern: #"^(?:#|[-*+] |>|<!--|\d+[.)] )"#)


    /// Whether the text contains at least one item line with a checkbox, checked without reading anything else.
    public static func containsCheckboxItems(_ text: String) -> Bool {
        checkboxLineAnywhereRegex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }


    /// Whether the text opens with a version marker, whatever its version.
    public static func startsWithVersionMarker(_ text: String) -> Bool {
        guard let firstLine = text.split(whereSeparator: \.isNewline).first(where: { !$0.allSatisfy(\.isWhitespace) }) else { return false }
        return firstMatch(versionMarkerRegex, in: firstLine.trimmingCharacters(in: .whitespaces)) != nil
    }


    /// Parses any text as Stuff Markdown.
    ///
    /// Lines that aren't part of Stuff Markdown, such as paragraphs between items or numbered lists, are skipped, so any text gives a document, possibly an empty one.
    /// - Parameters:
    ///   - text: The text to read.
    ///   - options: Which Tags and legacy dates the app can import. The default reads every detail.
    public static func parse(_ text: String, options: ParseOptions = ParseOptions()) -> Document {
        var parser = Parser(options: options)
        /// `\r\n` is one `Character`, so Windows line endings split once rather than leaving an empty line that would end an item's notes.
        for line in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
            parser.read(String(line))
        }
        return parser.finish()
    }


    /// Returns the first match of a regex across the whole string.
    fileprivate static func firstMatch(_ regex: NSRegularExpression, in text: String) -> NSTextCheckingResult? {
        regex.firstMatch(in: text, range: NSRange(location: 0, length: (text as NSString).length))
    }



    // MARK: - Parser
    /// Reads a document one line at a time.
    private struct Parser {
        /// What the quoted lines being read are notes for.
        private enum NotesOwner {
            case title
            case sectionHeader
            case item(Item)
        }

        /// The document read so far, without the section still open.
        private var document = Document()

        /// The section items are being added to.
        private var openSection: Section?

        /// The title, header, or item whose notes are being read.
        private var notesOwner: NotesOwner?

        /// The note lines read for `notesOwner`.
        private var noteLines: [String] = []

        /// Whether a blank line came after the last item, so the next item starts a new group.
        private var hasBlankLineSinceItem = false

        /// Whether a non-blank line has been read, after which a version marker no longer counts.
        private var hasReadContent = false

        /// The `tagKey` of every known Tag, or `nil` when every `#Tag` is read.
        private let knownTagKeys: Set<String>?

        /// The app's parse options.
        private let options: ParseOptions


        /// Creates a parser.
        init(options: ParseOptions) {
            self.options = options
            self.knownTagKeys = options.knownTags.map { Set($0.map(StuffMarkdown.tagKey)) }
        }


        /// Reads one line.
        mutating func read(_ line: String) {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            guard !trimmedLine.isEmpty else {
                /// A blank line ends notes, and separates groups of items.
                finishNotes()
                hasBlankLineSinceItem = true
                return
            }
            defer { hasReadContent = true }

            if !hasReadContent, let match = firstMatch(versionMarkerRegex, in: trimmedLine) {
                document.version = Int((trimmedLine as NSString).substring(with: match.range(at: 1)))
                return
            }

            if let match = firstMatch(checkboxLineRegex, in: line) {
                let source = line as NSString
                readCheckboxItems(checkboxCharacter: source.substring(with: match.range(at: 1)),
                                  text: source.substring(with: match.range(at: 2)))
                return
            }

            if readNoteLine(line, trimmedLine: trimmedLine) {
                return
            }
            finishNotes()

            if let match = firstMatch(headerLineRegex, in: line) {
                let source = line as NSString
                readHeader(level: match.range(at: 1).length, text: source.substring(with: match.range(at: 2)))
            } else if let match = firstMatch(plainItemLineRegex, in: line) {
                startItem(status: nil, text: (line as NSString).substring(with: match.range(at: 1)))
            }
            /// Anything else outside an item, such as a paragraph or a numbered list, isn't part of Stuff Markdown and is skipped.
        }


        /// Ends the document, adding whatever is still open.
        mutating func finish() -> Document {
            finishNotes()
            closeSection()
            return document
        }



        // MARK: Lines
        /// Reads a checkbox line, which may hold several items when its line breaks were lost, as in `- [ ] A - [ ] B`.
        private mutating func readCheckboxItems(checkboxCharacter: String, text: String) {
            let source = text as NSString
            let markers = inlineCheckboxRegex.matches(in: text, range: NSRange(location: 0, length: source.length))

            var character = checkboxCharacter
            var start = 0
            for marker in markers {
                startItem(status: status(for: character),
                          text: source.substring(with: NSRange(location: start, length: marker.range.location - start)))
                character = source.substring(with: marker.range(at: 1))
                start = marker.range.location + marker.range.length
            }
            startItem(status: status(for: character), text: source.substring(from: start))
        }


        /// Adds a line to the notes being read, returning whether it was one.
        ///
        /// A quoted line is a note under any title, header, or item. Under an item, an indented line is also a note, and so is unindented text that isn't Markdown structure, which is how hard-wrapped Markdown continues an item.
        private mutating func readNoteLine(_ line: String, trimmedLine: String) -> Bool {
            guard let notesOwner else { return false }

            if trimmedLine.hasPrefix(">") {
                noteLines.append(Self.quotedNoteText(line, trimmedLine: trimmedLine))
                return true
            }

            guard case .item = notesOwner else { return false }
            if line.first?.isWhitespace == true || firstMatch(structureLineRegex, in: line) == nil {
                noteLines.append(trimmedLine)
                return true
            }
            return false
        }


        /// Reads a header: the first `#` before any items is the title, and every other header opens a section.
        private mutating func readHeader(level: Int, text: String) {
            hasBlankLineSinceItem = false
            let header = makeHeader(text: text)

            if level == 1, document.title == nil, document.sections.isEmpty, openSection == nil {
                document.title = header
                notesOwner = .title
                return
            }

            closeSection()
            openSection = Section(header: header)
            notesOwner = .sectionHeader
        }


        /// Starts reading an item, whose notes may follow.
        private mutating func startItem(status: Status?, text: String) {
            finishNotes()
            guard let item = makeItem(status: status, text: text) else { return }

            if hasBlankLineSinceItem, openSection?.items.isEmpty == false {
                closeSection()
            }
            hasBlankLineSinceItem = false
            notesOwner = .item(item)
        }


        /// Attaches the notes read so far to their owner, adding an item to its section.
        private mutating func finishNotes() {
            defer {
                notesOwner = nil
                noteLines = []
            }
            guard let notesOwner else { return }

            while noteLines.last?.trimmingCharacters(in: .whitespaces).isEmpty == true {
                noteLines.removeLast()
            }
            let notes = noteLines.isEmpty ? nil : noteLines.joined(separator: "\n")

            switch notesOwner {
            case .title:
                document.title?.notes = notes
            case .sectionHeader:
                openSection?.header?.notes = notes
            case .item(var item):
                item.notes = notes
                if openSection == nil {
                    openSection = Section()
                }
                openSection?.items.append(item)
            }
        }


        /// Adds the open section to the document, unless it's an empty group without a header.
        private mutating func closeSection() {
            defer { openSection = nil }
            guard let openSection, openSection.header != nil || !openSection.items.isEmpty else { return }
            document.sections.append(openSection)
        }



        // MARK: Building
        /// Creates an item from a line's text, or `nil` when it has no name.
        private func makeItem(status: Status?, text: String) -> Item? {
            let (name, details) = nameAndDetails(text)
            guard !name.isEmpty else { return nil }
            return Item(status: status, name: name, details: details)
        }


        /// Creates a header from a line's text.
        private func makeHeader(text: String) -> Header {
            let (name, details) = nameAndDetails(text)
            return Header(name: name, details: details)
        }


        /// Splits a line's text into its unescaped name and its details.
        ///
        /// A line that's only details, such as `*Someday*`, keeps its text as the name rather than losing it.
        private func nameAndDetails(_ text: String) -> (name: String, details: Details) {
            var reader = DetailReader(text: text, options: options, knownTagKeys: knownTagKeys)
            reader.read()

            let name = StuffMarkdown.unescapedName(reader.name)
            guard name.isEmpty else { return (name, reader.details) }
            return (StuffMarkdown.unescapedName(text), Details())
        }


        /// The status written by a checkbox character.
        private func status(for checkboxCharacter: String) -> Status {
            checkboxCharacter.first.flatMap(Status.init(checkboxCharacter:)) ?? .available
        }


        /// Returns a quoted note line's text without its `>` and the space after it.
        ///
        /// Exports before Stuff Markdown wrote notes as `   >  Note`, with two spaces after the `>`, so both are removed there.
        private static func quotedNoteText(_ line: String, trimmedLine: String) -> String {
            var noteText = trimmedLine.dropFirst()
            let spacesToRemove = line.hasPrefix("   >  ") ? 2 : 1
            for _ in 0..<spacesToRemove where noteText.first == " " {
                noteText = noteText.dropFirst()
            }
            return String(noteText)
        }
    }
}
