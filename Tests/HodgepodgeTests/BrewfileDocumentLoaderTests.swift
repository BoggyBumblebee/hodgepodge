import Foundation
import XCTest
@testable import Hodgepodge

final class BrewfileDocumentLoaderTests: XCTestCase {
    func testLoadDocumentParsesEntriesCommentsAndUnknownLines() throws {
        let fileURL = try makeTemporaryBrewfile(
            contents: """
            tap "homebrew/cask"
            brew "wget", restart_service: true, args: ["HEAD"] # keep current
            # desktop apps
            cask "visual-studio-code"
            brewfile_command something
            """
        )

        let document = try BrewfileDocumentLoader().loadDocument(at: fileURL)

        XCTAssertEqual(document.entryCount, 3)
        XCTAssertEqual(document.commentCount, 1)
        XCTAssertEqual(document.unknownCount, 1)
        XCTAssertEqual(document.entries.map(\.name), ["homebrew/cask", "wget", "visual-studio-code"])
        XCTAssertEqual(document.entries[1].options["restart_service"], "true")
        XCTAssertEqual(document.entries[1].options["args"], #"["HEAD"]"#)
        XCTAssertEqual(document.entries[1].inlineComment, "keep current")
        XCTAssertEqual(document.lines[2].commentText, "desktop apps")
        XCTAssertEqual(document.lines[4].category, .unknown)
    }

    func testLoadDocumentIgnoresBlankLinesAndRetainsLineNumbers() throws {
        let fileURL = try makeTemporaryBrewfile(
            contents: """

            tap "homebrew/cask"

            # tools
            """
        )

        let document = try BrewfileDocumentLoader().loadDocument(at: fileURL)

        XCTAssertEqual(document.lines.map(\.lineNumber), [2, 4])
        XCTAssertEqual(document.lines.map(\.category), [.entry, .comment])
    }

    private func makeTemporaryBrewfile(contents: String) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("Brewfile", isDirectory: false)
        try contents.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }
}
