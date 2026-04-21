import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewOutdatedPackagesProviderTests: XCTestCase {
    func testFetchOutdatedPackagesMapsFormulaeAndCasks() async throws {
        let provider = BrewOutdatedPackagesProvider(
            brewLocator: OutdatedProviderTestBrewLocator(),
            runner: OutdatedProviderTestCommandRunner(
                stdout:
                    """
                    {
                      "formulae": [
                        {
                          "name": "homebrew/core/wget",
                          "installed_versions": ["1.24.5"],
                          "current_version": "1.25.0",
                          "pinned": true,
                          "pinned_version": "1.24.5"
                        }
                      ],
                      "casks": [
                        {
                          "name": "docker-desktop",
                          "installed_versions": ["4.67.0"],
                          "current_version": "4.68.0"
                        }
                      ]
                    }
                    """
            )
        )

        let packages = try await provider.fetchOutdatedPackages()

        XCTAssertEqual(packages.map(\.title), ["docker-desktop", "wget"])
        XCTAssertEqual(packages[0].kind, .cask)
        XCTAssertEqual(packages[0].installedVersions, ["4.67.0"])
        XCTAssertEqual(packages[0].currentVersion, "4.68.0")
        XCTAssertFalse(packages[0].isPinned)

        XCTAssertEqual(packages[1].kind, .formula)
        XCTAssertEqual(packages[1].fullName, "homebrew/core/wget")
        XCTAssertEqual(packages[1].slug, "wget")
        XCTAssertEqual(packages[1].installedVersions, ["1.24.5"])
        XCTAssertEqual(packages[1].currentVersion, "1.25.0")
        XCTAssertTrue(packages[1].isPinned)
        XCTAssertEqual(packages[1].pinnedVersion, "1.24.5")
    }

    func testFetchOutdatedPackagesDefaultsMissingCollections() async throws {
        let provider = BrewOutdatedPackagesProvider(
            brewLocator: OutdatedProviderTestBrewLocator(),
            runner: OutdatedProviderTestCommandRunner(
                stdout:
                    """
                    {
                      "formulae": [
                        {
                          "name": "homebrew/core/act",
                          "current_version": "0.2.81"
                        }
                      ],
                      "casks": [
                        {
                          "name": "raycast",
                          "current_version": "1.90.0"
                        }
                      ]
                    }
                    """
            )
        )

        let packages = try await provider.fetchOutdatedPackages()

        XCTAssertEqual(packages.count, 2)
        XCTAssertEqual(packages[0].installedVersions, [])
        XCTAssertEqual(packages[1].installedVersions, [])
        XCTAssertFalse(packages[0].isPinned)
        XCTAssertFalse(packages[1].isPinned)
    }
}

private struct OutdatedProviderTestBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

private struct OutdatedProviderTestCommandRunner: CommandRunning {
    let stdout: String

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        CommandResult(stdout: stdout, stderr: "", exitCode: 0)
    }
}
