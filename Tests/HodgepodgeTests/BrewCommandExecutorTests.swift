import XCTest
@testable import Hodgepodge

@MainActor
final class BrewCommandExecutorTests: XCTestCase {
    func testExecuteUsesLocatedBrewPathAndStreamsLogs() async throws {
        let runner = RecordingCommandRunner(
            result: .success(CommandResult(stdout: "done\n", stderr: "", exitCode: 0)),
            chunks: [
                CommandOutputChunk(stream: .stdout, text: "Downloading...\n")
            ]
        )
        let executor = BrewCommandExecutor(
            brewLocator: FixedBrewLocator(),
            runner: runner
        )
        let command = CatalogPackageDetail.fixture().actionCommand(for: .fetch)
        var logs: [(CatalogPackageActionLogKind, String)] = []

        let result = try await executor.execute(command: command) { kind, text in
            logs.append((kind, text))
        }

        XCTAssertEqual(runner.executable, "/opt/homebrew/bin/brew")
        XCTAssertEqual(runner.arguments, ["fetch", "wget"])
        XCTAssertEqual(result, CommandResult(stdout: "done\n", stderr: "", exitCode: 0))
        XCTAssertEqual(
            logs.map(\.1),
            [
                "Using Homebrew at /opt/homebrew/bin/brew",
                "$ /opt/homebrew/bin/brew fetch wget",
                "Downloading...\n"
            ]
        )
    }
}

private struct FixedBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

@MainActor
private final class RecordingCommandRunner: CommandRunning, @unchecked Sendable {
    let result: Result<CommandResult, Error>
    let chunks: [CommandOutputChunk]
    private(set) var executable: String?
    private(set) var arguments: [String] = []

    init(
        result: Result<CommandResult, Error>,
        chunks: [CommandOutputChunk] = []
    ) {
        self.result = result
        self.chunks = chunks
    }

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        self.executable = executable
        self.arguments = arguments

        for chunk in chunks {
            onOutput?(chunk)
        }

        return try result.get()
    }
}
