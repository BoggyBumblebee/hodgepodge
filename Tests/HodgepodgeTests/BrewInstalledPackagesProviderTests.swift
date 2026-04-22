import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewInstalledPackagesProviderTests: XCTestCase {
    func testFetchInstalledPackagesMapsFormulaeAndCasks() async throws {
        let provider = BrewInstalledPackagesProvider(
            brewLocator: ProviderTestBrewLocator(),
            runner: ProviderTestCommandRunner(
                infoStdout:
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
                          "dependencies": ["libidn2", "openssl@3"],
                          "build_dependencies": ["pkgconf"],
                          "test_dependencies": [],
                          "recommended_dependencies": [],
                          "optional_dependencies": [],
                          "requirements": [
                            {
                              "name": "xcode",
                              "version": "15.3",
                              "contexts": ["build"]
                            }
                          ],
                          "versions": {
                            "stable": "1.25.0",
                            "head": "HEAD"
                          },
                          "installed": [
                            {
                              "version": "1.25.0",
                              "time": 1710000000,
                              "runtime_dependencies": [
                                { "full_name": "libidn2", "declared_directly": true },
                                { "full_name": "openssl@3", "declared_directly": false }
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
                ,
                leavesStdout: "wget\n"
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
        XCTAssertTrue(packages[1].isLeaf)
        XCTAssertTrue(packages[1].isInstalledOnRequest)
        XCTAssertEqual(packages[1].directDependencies, ["libidn2", "openssl@3"])
        XCTAssertEqual(packages[1].buildDependencies, ["pkgconf"])
        XCTAssertEqual(packages[1].requirements, ["xcode 15.3 (build)"])
        XCTAssertEqual(packages[1].directRuntimeDependencies, ["libidn2"])
        XCTAssertEqual(packages[1].runtimeDependencies, ["libidn2", "openssl@3"])
    }

    func testFetchInstalledPackagesDefaultsMissingCollections() async throws {
        let provider = BrewInstalledPackagesProvider(
            brewLocator: ProviderTestBrewLocator(),
            runner: ProviderTestCommandRunner(
                infoStdout:
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
                ,
                leavesStdout: ""
            )
        )

        let packages = try await provider.fetchInstalledPackages()

        XCTAssertEqual(packages.count, 1)
        XCTAssertEqual(packages[0].subtitle, "No description available.")
        XCTAssertEqual(packages[0].version, "0.2.81")
        XCTAssertTrue(packages[0].runtimeDependencies.isEmpty)
    }

    func testFetchInstalledPackagesAcceptsFormulaOnlyArrayPayload() async throws {
        let provider = BrewInstalledPackagesProvider(
            brewLocator: ProviderTestBrewLocator(
                compatibility: HomebrewCompatibilitySnapshot(
                    version: HomebrewVersion(parsing: "5.1.7"),
                    infoJSONArgument: .plain,
                    outdatedJSONArgument: .versioned("v2"),
                    tapInfoJSONArgument: .versioned("v1"),
                    servicesListSupportsJSON: true,
                    servicesInfoSupportsJSON: true,
                    bundleSupportsNoUpgrade: true,
                    bundleSupportsFormulaDump: true,
                    bundleSupportsCaskDump: true,
                    supportedBundleAddKinds: Set(BrewfileEntryKind.addableCases),
                    supportedBundleRemoveKinds: Set(BrewfileEntryKind.allCases.filter(\.supportsBundleRemove))
                )
            ),
            runner: ProviderTestCommandRunner(
                infoStdout:
                    """
                    [
                      {
                        "name": "wget",
                        "full_name": "homebrew/core/wget",
                        "tap": "homebrew/core",
                        "desc": "Internet file retriever",
                        "homepage": "https://example.com/wget",
                        "versions": {
                          "stable": "1.25.0",
                          "head": null
                        },
                        "installed": [],
                        "linked_keg": null,
                        "pinned": false,
                        "outdated": false,
                        "deprecated": false,
                        "disabled": false
                      }
                    ]
                    """,
                leavesStdout: ""
            )
        )

        let packages = try await provider.fetchInstalledPackages()

        XCTAssertEqual(packages.map(\.title), ["wget"])
    }
}

private struct ProviderTestBrewLocator: BrewLocating {
    let compatibility: HomebrewCompatibilitySnapshot

    init(compatibility: HomebrewCompatibilitySnapshot = .modernDefault(version: "5.1.7")) {
        self.compatibility = compatibility
    }

    func locate() async throws -> HomebrewInstallation {
        .fixture(compatibility: compatibility)
    }
}

private struct ProviderTestCommandRunner: CommandRunning {
    let infoStdout: String
    let leavesStdout: String

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        let stdout = if arguments == ["info", "--json=v2", "--installed"] ||
            arguments == ["info", "--json", "--installed"] {
            infoStdout
        } else if arguments == ["leaves"] {
            leavesStdout
        } else {
            ""
        }

        return CommandResult(stdout: stdout, stderr: "", exitCode: 0)
    }
}
