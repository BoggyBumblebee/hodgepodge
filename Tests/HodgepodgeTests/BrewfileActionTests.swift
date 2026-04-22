import Foundation
import XCTest
@testable import Hodgepodge

final class BrewfileActionTests: XCTestCase {
    func testCheckCommandBuildsExpectedArguments() {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let command = BrewfileActionCommand(kind: .check, fileURL: fileURL)

        XCTAssertEqual(command.kind, .check)
        XCTAssertEqual(
            command.arguments,
            ["bundle", "check", "--file", "/tmp/Brewfile", "--verbose", "--no-upgrade"]
        )
        XCTAssertEqual(
            command.command,
            "brew bundle check --file /tmp/Brewfile --verbose --no-upgrade"
        )
    }

    func testInstallCommandBuildsExpectedArgumentsAndConfirmation() {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let command = BrewfileActionCommand(kind: .install, fileURL: fileURL)

        XCTAssertEqual(command.kind, .install)
        XCTAssertEqual(
            command.arguments,
            ["bundle", "install", "--file", "/tmp/Brewfile", "--verbose"]
        )
        XCTAssertEqual(
            command.command,
            "brew bundle install --file /tmp/Brewfile --verbose"
        )
        XCTAssertEqual(command.confirmationTitle, "Install Brewfile Dependencies?")
    }

    func testDumpCommandBuildsExpectedArguments() {
        let fileURL = URL(fileURLWithPath: "/tmp/ExportedBrewfile")
        let command = BrewfileActionCommand(kind: .dump, fileURL: fileURL)

        XCTAssertEqual(command.kind, .dump)
        XCTAssertEqual(
            command.arguments,
            ["bundle", "dump", "--file", "/tmp/ExportedBrewfile", "--force"]
        )
        XCTAssertEqual(
            command.command,
            "brew bundle dump --file /tmp/ExportedBrewfile --force"
        )
    }
}
