import Foundation
import XCTest
@testable import Hodgepodge

@MainActor
final class BrewMaintenanceProviderTests: XCTestCase {
    func testFetchDashboardParsesConfigDoctorAndDryRuns() async throws {
        let runner = MockMaintenanceCommandRunner(resultsByArguments: [
            ["config"]: .success(
                CommandResult(
                    stdout: "HOMEBREW_VERSION: 5.1.7\nHOMEBREW_PREFIX: /opt/homebrew\nmacOS: 26.4.1-arm64\n",
                    stderr: "",
                    exitCode: 0
                )
            ),
            ["doctor"]: .failure(
                CommandRunnerError.nonZeroExitCode(
                    CommandResult(
                        stdout: "",
                        stderr: "Warning: The following directories are not writable by your user.\n",
                        exitCode: 1
                    )
                )
            ),
            ["cleanup", "--dry-run"]: .success(
                CommandResult(
                    stdout: "Would remove: /tmp/cleanup.tar.gz\n==> This operation would free approximately 2.3KB of disk space.\n",
                    stderr: "",
                    exitCode: 0
                )
            ),
            ["autoremove", "--dry-run"]: .success(
                CommandResult(
                    stdout: "",
                    stderr: "Warning: Skipping pydantic: most recent version 2.13.3 not installed\n",
                    exitCode: 0
                )
            )
        ])
        let provider = BrewMaintenanceProvider(
            brewLocator: MockMaintenanceBrewLocator(),
            runner: runner
        )

        let dashboard = try await provider.fetchDashboard()

        XCTAssertEqual(dashboard.config.version, "5.1.7")
        XCTAssertEqual(dashboard.doctor.warningCount, 1)
        XCTAssertEqual(dashboard.cleanup.itemCount, 1)
        XCTAssertEqual(dashboard.cleanup.spaceFreedEstimate, "2.3KB")
        XCTAssertEqual(dashboard.autoremove.warnings, ["Skipping pydantic: most recent version 2.13.3 not installed"])
        let expectedArguments = [
            ["config"],
            ["doctor"],
            ["cleanup", "--dry-run"],
            ["autoremove", "--dry-run"]
        ]
        XCTAssertEqual(runner.recordedArguments.count, expectedArguments.count)
        XCTAssertEqual(Set(runner.recordedArguments), Set(expectedArguments))
    }
}

private struct MockMaintenanceBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

@MainActor
private final class MockMaintenanceCommandRunner: CommandRunning, @unchecked Sendable {
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
