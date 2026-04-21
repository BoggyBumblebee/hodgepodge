import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewInstalledPackagesProviderTests: XCTestCase {
    func testFetchInstalledPackagesMapsFormulaeAndCasks() async throws {
        let provider = BrewInstalledPackagesProvider(
            brewLocator: ProviderTestBrewLocator(),
            runner: ProviderTestCommandRunner(
                stdout:
                    """
                    {
                      "formulae": [
                        {
                          "name": "wget",
                          "full_name": "homebrew/core/wget",
                          "tap": "homebrew/core",
                          "desc": "Internet file retriever",
                          "homepage": "https://example.com/wget",
                          "aliases": [],
                          "oldnames": [],
                          "versions": {
                            "stable": "1.25.0",
                            "head": "HEAD"
                          },
                          "installed": [
                            {
                              "version": "1.25.0",
                              "time": 1710000000,
                              "runtime_dependencies": [
                                { "full_name": "libidn2" },
                                { "full_name": "openssl@3" }
                              ],
                              "installed_as_dependency": false,
                              "installed_on_request": true
                            }
                          ],
                          "linked_keg": "1.25.0",
                          "pinned": true,
                          "outdated": false,
                          "deprecated": false,
                          "disabled": false
                        }
                      ],
                      "casks": [
                        {
                          "token": "docker-desktop",
                          "full_token": "docker-desktop",
                          "tap": "homebrew/cask",
                          "name": ["Docker Desktop"],
                          "desc": "Container desktop app",
                          "homepage": "https://example.com/docker",
                          "version": "4.68.0",
                          "installed": "4.68.0",
                          "installed_time": 1711000000,
                          "outdated": true,
                          "auto_updates": true,
                          "deprecated": false,
                          "disabled": false
                        }
                      ]
                    }
                    """
            )
        )

        let packages = try await provider.fetchInstalledPackages()

        XCTAssertEqual(packages.map(\.title), ["Docker Desktop", "wget"])
        XCTAssertEqual(packages[0].kind, .cask)
        XCTAssertEqual(packages[0].version, "4.68.0")
        XCTAssertTrue(packages[0].autoUpdates)
        XCTAssertTrue(packages[0].isOutdated)

        XCTAssertEqual(packages[1].kind, .formula)
        XCTAssertEqual(packages[1].fullName, "homebrew/core/wget")
        XCTAssertEqual(packages[1].linkedVersion, "1.25.0")
        XCTAssertTrue(packages[1].isPinned)
        XCTAssertTrue(packages[1].isInstalledOnRequest)
        XCTAssertEqual(packages[1].runtimeDependencies, ["libidn2", "openssl@3"])
    }

    func testFetchInstalledPackagesDefaultsMissingCollections() async throws {
        let provider = BrewInstalledPackagesProvider(
            brewLocator: ProviderTestBrewLocator(),
            runner: ProviderTestCommandRunner(
                stdout:
                    """
                    {
                      "formulae": [
                        {
                          "name": "act",
                          "full_name": "homebrew/core/act",
                          "tap": "homebrew/core",
                          "desc": null,
                          "homepage": "https://example.com/act",
                          "versions": {
                            "stable": "0.2.81",
                            "head": null
                          },
                          "installed": [],
                          "linked_keg": null,
                          "pinned": false,
                          "outdated": false,
                          "deprecated": false,
                          "disabled": false
                        }
                      ],
                      "casks": []
                    }
                    """
            )
        )

        let packages = try await provider.fetchInstalledPackages()

        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].subtitle, "No description available.")
        XCTAssertEqual(packages[0].version, "0.2.81")
        XCTAssertTrue(packages[0].runtimeDependencies.isEmpty)
    }
}

private struct ProviderTestBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

private struct ProviderTestCommandRunner: CommandRunning {
    let stdout: String

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        CommandResult(stdout: stdout, stderr: "", exitCode: 0)
    }
}
