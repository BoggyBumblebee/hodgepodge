import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewTapsProviderTests: XCTestCase {
    func testFetchTapsUsesInstalledTapListAndMapsMetadata() async throws {
        let runner = MockBrewTapsCommandRunner(resultsByArguments: [
            ["tap"]: .success(CommandResult(
                stdout: "keith/formulae\ntimescale/tap\n",
                stderr: "",
                exitCode: 0
            )),
            ["tap-info", "--json=v1", "keith/formulae", "timescale/tap"]: .success(CommandResult(
                stdout: """
                [
                  {
                    "name": "keith/formulae",
                    "user": "keith",
                    "repo": "formulae",
                    "repository": "formulae",
                    "path": "/opt/homebrew/Library/Taps/keith/homebrew-formulae",
                    "official": false,
                    "formula_names": ["keith/formulae/xcpretty"],
                    "cask_tokens": ["keith/formulae/conductor"],
                    "formula_files": ["/opt/homebrew/Library/Taps/keith/homebrew-formulae/Formula/xcpretty.rb"],
                    "cask_files": ["/opt/homebrew/Library/Taps/keith/homebrew-formulae/Casks/conductor.rb"],
                    "command_files": [],
                    "remote": "https://github.com/keith/homebrew-formulae",
                    "custom_remote": false,
                    "private": false,
                    "HEAD": "abc123",
                    "last_commit": "6 weeks ago",
                    "branch": "master"
                  },
                  {
                    "name": "timescale/tap",
                    "user": "timescale",
                    "repo": "tap",
                    "repository": "tap",
                    "path": "/opt/homebrew/Library/Taps/timescale/homebrew-tap",
                    "official": false,
                    "formula_names": ["timescale/tap/timescaledb"],
                    "cask_tokens": [],
                    "formula_files": ["/opt/homebrew/Library/Taps/timescale/homebrew-tap/timescaledb.rb"],
                    "cask_files": [],
                    "command_files": [],
                    "remote": "https://github.com/timescale/homebrew-tap",
                    "custom_remote": false,
                    "private": false,
                    "HEAD": "def456",
                    "last_commit": "16 hours ago",
                    "branch": "main"
                  }
                ]
                """,
                stderr: "",
                exitCode: 0
            ))
        ])
        let provider = BrewTapsProvider(
            brewLocator: MockTapsBrewLocator(),
            runner: runner
        )

        let taps = try await provider.fetchTaps()

        XCTAssertEqual(taps.map(\.name), ["keith/formulae", "timescale/tap"])
        XCTAssertEqual(taps.first?.packageCount, 2)
        XCTAssertEqual(runner.recordedArguments, [
            ["tap"],
            ["tap-info", "--json=v1", "keith/formulae", "timescale/tap"]
        ])
    }

    func testFetchTapsReturnsEmptyWhenNothingInstalled() async throws {
        let runner = MockBrewTapsCommandRunner(resultsByArguments: [
            ["tap"]: .success(CommandResult(stdout: "", stderr: "", exitCode: 0))
        ])
        let provider = BrewTapsProvider(
            brewLocator: MockTapsBrewLocator(),
            runner: runner
        )

        let taps = try await provider.fetchTaps()

        XCTAssertTrue(taps.isEmpty)
        XCTAssertEqual(runner.recordedArguments, [["tap"]])
    }

    func testFetchTapsUsesPlainJSONWhenCompatibilityRequiresIt() async throws {
        let compatibility = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "5.1.7"),
            infoJSONArgument: .versioned("v2"),
            outdatedJSONArgument: .versioned("v2"),
            tapInfoJSONArgument: .plain,
            servicesListSupportsJSON: true,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: true,
            bundleSupportsFormulaDump: true,
            bundleSupportsCaskDump: true,
            supportedBundleAddKinds: Set(BrewfileEntryKind.addableCases),
            supportedBundleRemoveKinds: Set(BrewfileEntryKind.allCases.filter(\.supportsBundleRemove))
        )
        let runner = MockBrewTapsCommandRunner(resultsByArguments: [
            ["tap"]: .success(CommandResult(
                stdout: "keith/formulae\n",
                stderr: "",
                exitCode: 0
            )),
            ["tap-info", "--json", "keith/formulae"]: .success(CommandResult(
                stdout: """
                [
                  {
                    "name": "keith/formulae",
                    "user": "keith",
                    "repo": "formulae",
                    "repository": "formulae",
                    "path": "/opt/homebrew/Library/Taps/keith/homebrew-formulae",
                    "official": false,
                    "formula_names": [],
                    "cask_tokens": [],
                    "formula_files": [],
                    "cask_files": [],
                    "command_files": [],
                    "remote": "https://github.com/keith/homebrew-formulae",
                    "custom_remote": false,
                    "private": false,
                    "HEAD": "abc123",
                    "last_commit": "6 weeks ago",
                    "branch": "master"
                  }
                ]
                """,
                stderr: "",
                exitCode: 0
            ))
        ])
        let provider = BrewTapsProvider(
            brewLocator: MockTapsBrewLocator(compatibility: compatibility),
            runner: runner
        )

        let taps = try await provider.fetchTaps()

        XCTAssertEqual(taps.map(\.name), ["keith/formulae"])
        XCTAssertEqual(runner.recordedArguments, [["tap"], ["tap-info", "--json", "keith/formulae"]])
    }
}

private struct MockTapsBrewLocator: BrewLocating {
    let compatibility: HomebrewCompatibilitySnapshot

    init(compatibility: HomebrewCompatibilitySnapshot = .modernDefault(version: "5.1.7")) {
        self.compatibility = compatibility
    }

    func locate() async throws -> HomebrewInstallation {
        .fixture(compatibility: compatibility)
    }
}

@MainActor
private final class MockBrewTapsCommandRunner: CommandRunning, @unchecked Sendable {
    let resultsByArguments: [[String]: Result<CommandResult, Error>]
    private(set) var recordedArguments: [[String]] = []

    init(resultsByArguments: [[String]: Result<CommandResult, Error>]) {
        self.resultsByArguments = resultsByArguments
    }

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        recordedArguments.append(arguments)
        guard let result = resultsByArguments[arguments] else {
            XCTFail("Unexpected arguments: \(arguments)")
            return CommandResult(stdout: "", stderr: "", exitCode: 0)
        }

        return try result.get()
    }
}
