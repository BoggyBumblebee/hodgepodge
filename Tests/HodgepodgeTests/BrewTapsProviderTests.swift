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
}

private struct MockTapsBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
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
