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
        var logs: [(CatalogPackageActionLogKind, String)] = []

        let result = try await executor.execute(arguments: ["fetch", "wget"]) { kind, text in
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

    func testExecuteUsesCompatibilityAdjustedArguments() async throws {
        let runner = RecordingCommandRunner(
            result: .success(CommandResult(stdout: "", stderr: "", exitCode: 0))
        )
        let compatibility = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "5.1.7"),
            infoJSONArgument: .versioned("v2"),
            outdatedJSONArgument: .versioned("v2"),
            tapInfoJSONArgument: .plain,
            servicesListSupportsJSON: true,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: true,
            bundleSupportsFormulaDump: false,
            bundleSupportsCaskDump: true,
            supportedBundleAddKinds: Set(BrewfileEntryKind.addableCases),
            supportedBundleRemoveKinds: Set(BrewfileEntryKind.allCases.filter(\.supportsBundleRemove))
        )
        let executor = BrewCommandExecutor(
            brewLocator: FixedBrewLocator(compatibility: compatibility),
            runner: runner
        )
        var logs: [(CatalogPackageActionLogKind, String)] = []

        _ = try await executor.execute(arguments: ["bundle", "dump", "--file", "/tmp/Brewfile", "--force", "--cask"]) { kind, text in
            logs.append((kind, text))
        }

        XCTAssertEqual(runner.arguments, ["bundle", "dump", "--file", "/tmp/Brewfile", "--force", "--cask"])
        XCTAssertFalse(logs.map(\.1).contains("Adjusted command arguments for Homebrew 5.1.7."))
    }

    func testExecuteThrowsWhenCompatibilityRejectsBundleScope() async {
        let runner = RecordingCommandRunner(
            result: .success(CommandResult(stdout: "", stderr: "", exitCode: 0))
        )
        let compatibility = HomebrewCompatibilitySnapshot(
            version: HomebrewVersion(parsing: "5.1.7"),
            infoJSONArgument: .versioned("v2"),
            outdatedJSONArgument: .versioned("v2"),
            tapInfoJSONArgument: .plain,
            servicesListSupportsJSON: true,
            servicesInfoSupportsJSON: true,
            bundleSupportsNoUpgrade: true,
            bundleSupportsFormulaDump: false,
            bundleSupportsCaskDump: false,
            supportedBundleAddKinds: Set(BrewfileEntryKind.addableCases),
            supportedBundleRemoveKinds: Set(BrewfileEntryKind.allCases.filter(\.supportsBundleRemove))
        )
        let executor = BrewCommandExecutor(
            brewLocator: FixedBrewLocator(compatibility: compatibility),
            runner: runner
        )

        do {
            _ = try await executor.execute(arguments: ["bundle", "dump", "--file", "/tmp/Brewfile", "--force", "--formula"]) { _, _ in }
            XCTFail("Expected compatibility validation to reject the formula-only Brewfile export.")
        } catch {
            XCTAssertEqual(
                error as? HomebrewCompatibilityError,
                .unsupportedBundleDumpScope(scope: .formula, version: "5.1.7")
            )
        }
    }
}

private struct FixedBrewLocator: BrewLocating {
    let compatibility: HomebrewCompatibilitySnapshot

    init(compatibility: HomebrewCompatibilitySnapshot = .modernDefault(version: "5.1.7")) {
        self.compatibility = compatibility
    }

    func locate() async throws -> HomebrewInstallation {
        .fixture(compatibility: compatibility)
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
