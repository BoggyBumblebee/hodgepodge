import XCTest
@testable import Hodgepodge

@MainActor
final class BrewLocatorTests: XCTestCase {
    func testLocateReturnsDetectedInstallation() async throws {
        let runner = MockCommandRunner(
            responses: [
                MockCommand(
                    executable: "/opt/homebrew/bin/brew",
                    arguments: ["--version"],
                    result: .success(CommandResult(stdout: "Homebrew 5.1.7\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/opt/homebrew/bin/brew",
                    arguments: ["--prefix"],
                    result: .success(CommandResult(stdout: "/opt/homebrew\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/opt/homebrew/bin/brew",
                    arguments: ["--cellar"],
                    result: .success(CommandResult(stdout: "/opt/homebrew/Cellar\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/opt/homebrew/bin/brew",
                    arguments: ["--repository"],
                    result: .success(CommandResult(stdout: "/opt/homebrew/Homebrew\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/opt/homebrew/bin/brew",
                    arguments: ["tap"],
                    result: .success(CommandResult(stdout: "homebrew/core\nhomebrew/cask\n", stderr: "", exitCode: 0))
                )
            ]
        )

        let locator = BrewLocator(
            runner: runner,
            fileManager: MockFileManager(executablePaths: ["/opt/homebrew/bin/brew"]),
            clock: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let installation = try await locator.locate()

        XCTAssertEqual(installation.brewPath, "/opt/homebrew/bin/brew")
        XCTAssertEqual(installation.version, "5.1.7")
        XCTAssertEqual(installation.prefix, "/opt/homebrew")
        XCTAssertEqual(installation.cellar, "/opt/homebrew/Cellar")
        XCTAssertEqual(installation.repository, "/opt/homebrew/Homebrew")
        XCTAssertEqual(installation.taps, ["homebrew/core", "homebrew/cask"])
    }

    func testLocateThrowsWhenBrewCannotBeFound() async {
        let runner = MockCommandRunner(responses: [])
        let locator = BrewLocator(
            runner: runner,
            fileManager: MockFileManager(executablePaths: []),
            clock: Date.init
        )

        do {
            _ = try await locator.locate()
            XCTFail("Expected brew lookup to fail when no executable is available.")
        } catch {
            XCTAssertEqual(error as? BrewLocatorError, .brewNotFound)
        }
    }

    func testLocateUsesCustomExecutableCandidates() async throws {
        let runner = MockCommandRunner(
            responses: [
                MockCommand(
                    executable: "/custom/tools/brew",
                    arguments: ["--version"],
                    result: .success(CommandResult(stdout: "Homebrew 5.1.7\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/custom/tools/brew",
                    arguments: ["--prefix"],
                    result: .success(CommandResult(stdout: "/custom\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/custom/tools/brew",
                    arguments: ["--cellar"],
                    result: .success(CommandResult(stdout: "/custom/Cellar\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/custom/tools/brew",
                    arguments: ["--repository"],
                    result: .success(CommandResult(stdout: "/custom/Homebrew\n", stderr: "", exitCode: 0))
                ),
                MockCommand(
                    executable: "/custom/tools/brew",
                    arguments: ["tap"],
                    result: .success(CommandResult(stdout: "homebrew/core\n", stderr: "", exitCode: 0))
                )
            ]
        )

        let locator = BrewLocator(
            runner: runner,
            fileManager: MockFileManager(executablePaths: ["/custom/tools/brew"]),
            clock: Date.init,
            executableCandidates: ["/custom/tools/brew"]
        )

        let installation = try await locator.locate()

        XCTAssertEqual(installation.brewPath, "/custom/tools/brew")
        XCTAssertEqual(installation.prefix, "/custom")
    }
}

private struct MockCommand {
    let executable: String
    let arguments: [String]
    let result: Result<CommandResult, Error>
}

private struct MockCommandRunner: CommandRunning {
    let responses: [MockCommand]

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        guard let response = responses.first(where: { $0.executable == executable && $0.arguments == arguments }) else {
            throw BrewLocatorError.brewNotFound
        }

        return try response.result.get()
    }
}

private final class MockFileManager: FileManager, @unchecked Sendable {
    private let executablePaths: Set<String>

    init(executablePaths: Set<String>) {
        self.executablePaths = executablePaths
        super.init()
    }

    override func isExecutableFile(atPath path: String) -> Bool {
        executablePaths.contains(path)
    }
}
