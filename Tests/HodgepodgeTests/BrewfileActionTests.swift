import Foundation
import XCTest
@testable import Hodgepodge

final class BrewfileActionTests: XCTestCase {
    func testActionKindsExposeStableLabelsAndBehavior() {
        XCTAssertEqual(BrewfileActionKind.check.title, "Bundle Check")
        XCTAssertEqual(BrewfileActionKind.check.actionLabel, "Run Check")
        XCTAssertEqual(
            BrewfileActionKind.check.subtitle,
            "Verify that every dependency in this Brewfile is installed on the current Mac."
        )
        XCTAssertEqual(BrewfileActionKind.check.systemImageName, "checklist")
        XCTAssertFalse(BrewfileActionKind.check.requiresConfirmation)

        XCTAssertEqual(BrewfileActionKind.install.title, "Bundle Install")
        XCTAssertEqual(BrewfileActionKind.install.actionLabel, "Install")
        XCTAssertEqual(
            BrewfileActionKind.install.subtitle,
            "Install and upgrade the dependencies declared in this Brewfile."
        )
        XCTAssertEqual(BrewfileActionKind.install.systemImageName, "square.and.arrow.down")
        XCTAssertTrue(BrewfileActionKind.install.requiresConfirmation)

        XCTAssertEqual(BrewfileActionKind.dump.title, "Bundle Dump")
        XCTAssertEqual(BrewfileActionKind.dump.actionLabel, "Export Brewfile...")
        XCTAssertEqual(
            BrewfileActionKind.dump.subtitle,
            "Export Homebrew's current installed snapshot to a Brewfile."
        )
        XCTAssertEqual(BrewfileActionKind.dump.systemImageName, "square.and.arrow.up")
        XCTAssertFalse(BrewfileActionKind.dump.requiresConfirmation)

        XCTAssertEqual(BrewfileActionKind.add.title, "Bundle Add")
        XCTAssertEqual(BrewfileActionKind.add.actionLabel, "Add Entry")
        XCTAssertEqual(
            BrewfileActionKind.add.subtitle,
            "Add a new dependency entry to this Brewfile using Homebrew Bundle."
        )
        XCTAssertEqual(BrewfileActionKind.add.systemImageName, "plus.circle")
        XCTAssertFalse(BrewfileActionKind.add.requiresConfirmation)

        XCTAssertEqual(BrewfileActionKind.remove.title, "Bundle Remove")
        XCTAssertEqual(BrewfileActionKind.remove.actionLabel, "Remove Entry")
        XCTAssertEqual(
            BrewfileActionKind.remove.subtitle,
            "Remove the selected dependency entry from this Brewfile using Homebrew Bundle."
        )
        XCTAssertEqual(BrewfileActionKind.remove.systemImageName, "minus.circle")
        XCTAssertTrue(BrewfileActionKind.remove.requiresConfirmation)
    }

    func testCheckCommandBuildsExpectedArguments() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let command = try XCTUnwrap(BrewfileActionCommand.make(kind: .check, fileURL: fileURL))

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

    func testInstallCommandBuildsExpectedArgumentsAndConfirmation() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let command = try XCTUnwrap(BrewfileActionCommand.make(kind: .install, fileURL: fileURL))

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
        XCTAssertEqual(
            command.confirmationMessage,
            "Hodgepodge will run `brew bundle install --file /tmp/Brewfile --verbose` using your local Homebrew installation."
        )
    }

    func testDumpCommandBuildsExpectedArguments() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/ExportedBrewfile")
        let command = try XCTUnwrap(BrewfileActionCommand.make(kind: .dump, fileURL: fileURL))

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

    func testAddCommandBuildsExpectedArgumentsForFormulaAndCaskEntries() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let formulaCommand = try XCTUnwrap(BrewfileActionCommand.make(
            kind: .add,
            fileURL: fileURL,
            entryName: "wget",
            entryKind: .brew
        ))
        let caskCommand = try XCTUnwrap(BrewfileActionCommand.make(
            kind: .add,
            fileURL: fileURL,
            entryName: "visual-studio-code",
            entryKind: .cask
        ))

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

    func testRemoveCommandBuildsExpectedArgumentsForSelectedEntryKind() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")
        let command = try XCTUnwrap(BrewfileActionCommand.make(
            kind: .remove,
            fileURL: fileURL,
            entryName: "wget",
            entryKind: .brew
        ))

        XCTAssertEqual(
            command.arguments,
            ["bundle", "remove", "--formula", "wget", "--file", "/tmp/Brewfile"]
        )
        XCTAssertEqual(command.confirmationTitle, "Remove Brewfile Entry?")
        XCTAssertEqual(
            command.confirmationMessage,
            "Hodgepodge will run `brew bundle remove --formula wget --file /tmp/Brewfile` to update the Brewfile entry for `wget`."
        )
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

    func testAddCommandReturnsNilForUnsupportedOrEmptyEntries() {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")

        XCTAssertNil(
            BrewfileActionCommand.make(
                kind: .add,
                fileURL: fileURL,
                entryName: "Xcode",
                entryKind: .mas
            )
        )
        XCTAssertNil(
            BrewfileActionCommand.make(
                kind: .add,
                fileURL: fileURL,
                entryName: nil,
                entryKind: .brew
            )
        )
    }

    func testRemoveCommandReturnsNilForUnsupportedEntries() {
        let fileURL = URL(fileURLWithPath: "/tmp/Brewfile")

        XCTAssertNil(
            BrewfileActionCommand.make(
                kind: .remove,
                fileURL: fileURL,
                entryName: "mystery",
                entryKind: .unknown
            )
        )
        XCTAssertNil(
            BrewfileActionCommand.make(
                kind: .remove,
                fileURL: fileURL,
                entryName: nil,
                entryKind: .brew
            )
        )
    }
}
