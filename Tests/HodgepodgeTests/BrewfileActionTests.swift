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

    func testAddCommandBuildsExpectedArgumentsForFormulaAndCaskEntries() {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let formulaCommand = BrewfileActionCommand(
            kind: .add,
            fileURL: fileURL,
            entryName: "wget",
            entryKind: .brew
        )
        let caskCommand = BrewfileActionCommand(
            kind: .add,
            fileURL: fileURL,
            entryName: "visual-studio-code",
            entryKind: .cask
        )

        XCTAssertEqual(
            formulaCommand.arguments,
            ["bundle", "add", "wget", "--file", "/tmp/Brewfile"]
        )
        XCTAssertEqual(
            formulaCommand.command,
            "brew bundle add wget --file /tmp/Brewfile"
        )
        XCTAssertEqual(
            caskCommand.arguments,
            ["bundle", "add", "--cask", "visual-studio-code", "--file", "/tmp/Brewfile"]
        )
    }

    func testRemoveCommandBuildsExpectedArgumentsForSelectedEntryKind() {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let command = BrewfileActionCommand(
            kind: .remove,
            fileURL: fileURL,
            entryName: "wget",
            entryKind: .brew
        )

        XCTAssertEqual(
            command.arguments,
            ["bundle", "remove", "--formula", "wget", "--file", "/tmp/Brewfile"]
        )
        XCTAssertEqual(command.confirmationTitle, "Remove Brewfile Entry?")
    }

    func testEntryDraftOnlyBuildsCommandsForSupportedKindsWithNames() {
        var draft = BrewfileEntryDraft(kind: .brew, name: "wget")
        XCTAssertTrue(draft.isValid)
        XCTAssertEqual(
            draft.command(fileURL: URL(fileURLWithPath: "/tmp/Brewfile"))?.arguments,
            ["bundle", "add", "wget", "--file", "/tmp/Brewfile"]
        )

        draft = BrewfileEntryDraft(kind: .mas, name: "Xcode")
        XCTAssertFalse(draft.isValid)
        XCTAssertNil(draft.command(fileURL: URL(fileURLWithPath: "/tmp/Brewfile")))
    }

    func testEntryKindsExposeBundleAddSupportAndFlags() {
        XCTAssertTrue(BrewfileEntryKind.brew.supportsBundleAdd)
        XCTAssertNil(BrewfileEntryKind.brew.bundleAddFlag)

        XCTAssertTrue(BrewfileEntryKind.cask.supportsBundleAdd)
        XCTAssertEqual(BrewfileEntryKind.cask.bundleAddFlag, "--cask")

        XCTAssertFalse(BrewfileEntryKind.mas.supportsBundleAdd)
        XCTAssertNil(BrewfileEntryKind.mas.bundleAddFlag)

        XCTAssertFalse(BrewfileEntryKind.unknown.supportsBundleAdd)
        XCTAssertNil(BrewfileEntryKind.unknown.bundleAddFlag)
        XCTAssertTrue(BrewfileEntryKind.addableCases.contains(.brew))
        XCTAssertFalse(BrewfileEntryKind.addableCases.contains(.mas))
    }

    func testEntryKindsExposeBundleRemoveSupportAndFlags() {
        XCTAssertTrue(BrewfileEntryKind.brew.supportsBundleRemove)
        XCTAssertEqual(BrewfileEntryKind.brew.bundleRemoveFlag, "--formula")

        XCTAssertTrue(BrewfileEntryKind.tap.supportsBundleRemove)
        XCTAssertEqual(BrewfileEntryKind.tap.bundleRemoveFlag, "--tap")

        XCTAssertTrue(BrewfileEntryKind.mas.supportsBundleRemove)
        XCTAssertEqual(BrewfileEntryKind.mas.bundleRemoveFlag, "--mas")

        XCTAssertFalse(BrewfileEntryKind.unknown.supportsBundleRemove)
        XCTAssertNil(BrewfileEntryKind.unknown.bundleRemoveFlag)
    }
}
