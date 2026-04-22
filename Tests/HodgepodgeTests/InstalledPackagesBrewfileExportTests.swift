import Foundation
import XCTest
@testable import Hodgepodge

final class InstalledPackagesBrewfileExportTests: XCTestCase {
    func testCommandBuildsExpectedArgumentsForAllScope() {
        let command = InstalledPackagesBrewfileExportCommand(
            scope: .all,
            destinationURL: URL(fileURLWithPath: "/tmp/Brewfile")
        )

        XCTAssertEqual(
            command.arguments,
            ["bundle", "dump", "--file", "/tmp/Brewfile", "--force"]
        )
        XCTAssertEqual(command.suggestedFileName, "Brewfile")
    }

    func testCommandBuildsExpectedArgumentsForFormulaAndCaskScopes() {
        let formulaCommand = InstalledPackagesBrewfileExportCommand(
            scope: .formula,
            destinationURL: URL(fileURLWithPath: "/tmp/Brewfile-formulae")
        )
        let caskCommand = InstalledPackagesBrewfileExportCommand(
            scope: .cask,
            destinationURL: URL(fileURLWithPath: "/tmp/Brewfile-casks")
        )

        XCTAssertEqual(
            formulaCommand.arguments,
            ["bundle", "dump", "--file", "/tmp/Brewfile-formulae", "--force", "--formula"]
        )
        XCTAssertEqual(
            caskCommand.arguments,
            ["bundle", "dump", "--file", "/tmp/Brewfile-casks", "--force", "--cask"]
        )
        XCTAssertEqual(formulaCommand.suggestedFileName, "Brewfile-formulae")
        XCTAssertEqual(caskCommand.suggestedFileName, "Brewfile-casks")
    }
}
