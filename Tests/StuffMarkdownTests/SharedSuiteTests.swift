//
//  SharedSuiteTests.swift
//  StuffMarkdown
//
//  Created by Austin Blake on 10/26/26.
//

import Foundation
import Testing
@testable import StuffMarkdown

/// Runs every case in the shared `suite/cases` suite, which every Stuff Markdown implementation checks against.
struct SharedSuiteTests {
    /// One case folder: its input, the document it must parse to, and how to run it.
    struct SuiteCase: CustomTestStringConvertible, Sendable {
        /// The folder's name, such as "001-statuses".
        let name: String

        /// The folder's location.
        let folder: URL

        var testDescription: String { name }
    }


    /// The settings in a case's `case.json`.
    struct CaseSettings: Decodable {
        /// What the case checks.
        let description: String

        /// Whether writing the expected document must give back `input.md` exactly.
        let canonical: Bool?

        /// The Tags the app has, limiting which `#Tag` words are read.
        let knownTags: [String]?
    }


    /// The `suite/cases` folder at the repository's root.
    static let casesFolder = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appending(path: "suite/cases")

    /// Every case folder, in order.
    static let cases: [SuiteCase] = {
        let folders = (try? FileManager.default.contentsOfDirectory(at: casesFolder, includingPropertiesForKeys: nil)) ?? []
        return folders
            .filter { $0.hasDirectoryPath }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { SuiteCase(name: $0.lastPathComponent, folder: $0) }
    }()


    @Test func suiteIsPresent() {
        #expect(Self.cases.count > 30)
    }


    @Test(arguments: cases)
    func parsesToExpectedDocument(_ suiteCase: SuiteCase) throws {
        let (input, settings, expected) = try load(suiteCase)
        let document = StuffMarkdown.parse(input, options: StuffMarkdown.ParseOptions(knownTags: settings.knownTags))
        #expect(document == expected, "\(settings.description)")
    }


    @Test(arguments: cases)
    func writesCanonicalInputBack(_ suiteCase: SuiteCase) throws {
        let (input, settings, expected) = try load(suiteCase)
        guard settings.canonical == true else { return }
        #expect(StuffMarkdown.write(expected) + "\n" == input, "\(settings.description)")
    }


    @Test(arguments: cases)
    func expectedDocumentEncodesToItsJSON(_ suiteCase: SuiteCase) throws {
        let (_, _, expected) = try load(suiteCase)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(expected)
        let expectedJSON = try Data(contentsOf: suiteCase.folder.appending(path: "expected.json"))
        let roundTripped = try JSONSerialization.jsonObject(with: encoded) as? NSDictionary
        let original = try JSONSerialization.jsonObject(with: expectedJSON) as? NSDictionary
        #expect(roundTripped == original)
    }


    /// Reads a case's input, settings, and expected document.
    private func load(_ suiteCase: SuiteCase) throws -> (String, CaseSettings, StuffMarkdown.Document) {
        let input = try String(contentsOf: suiteCase.folder.appending(path: "input.md"), encoding: .utf8)
        let settings = try JSONDecoder().decode(CaseSettings.self, from: Data(contentsOf: suiteCase.folder.appending(path: "case.json")))
        let expected = try JSONDecoder().decode(StuffMarkdown.Document.self, from: Data(contentsOf: suiteCase.folder.appending(path: "expected.json")))
        return (input, settings, expected)
    }
}
