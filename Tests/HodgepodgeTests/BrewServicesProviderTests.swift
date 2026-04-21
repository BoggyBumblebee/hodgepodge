import XCTest
@testable import Hodgepodge

@MainActor
final class BrewServicesProviderTests: XCTestCase {
    func testFetchServicesMergesListAndInfoPayloads() async throws {
        let provider = BrewServicesProvider(
            brewLocator: ServicesProviderTestBrewLocator(),
            runner: ServicesProviderTestCommandRunner(
                responses: [
                    """
                    [
                      {
                        "name": "grafana",
                        "status": "none",
                        "user": null,
                        "file": "/opt/homebrew/opt/grafana/homebrew.mxcl.grafana.plist",
                        "exit_code": null
                      }
                    ]
                    """,
                    """
                    [
                      {
                        "name": "grafana",
                        "service_name": "homebrew.mxcl.grafana",
                        "running": false,
                        "loaded": false,
                        "schedulable": false,
                        "pid": null,
                        "exit_code": null,
                        "user": null,
                        "status": "none",
                        "file": "/opt/homebrew/opt/grafana/homebrew.mxcl.grafana.plist",
                        "registered": false,
                        "loaded_file": null,
                        "command": "/opt/homebrew/opt/grafana/bin/grafana server",
                        "working_dir": "/opt/homebrew/var/lib/grafana",
                        "root_dir": null,
                        "log_path": "/opt/homebrew/var/log/grafana-stdout.log",
                        "error_log_path": "/opt/homebrew/var/log/grafana-stderr.log",
                        "interval": null,
                        "cron": null
                      }
                    ]
                    """
                ]
            )
        )

        let services = try await provider.fetchServices()

        XCTAssertEqual(services, [
            BrewService.fixture(
                name: "grafana",
                serviceName: "homebrew.mxcl.grafana",
                status: "none",
                isRunning: false,
                isLoaded: false,
                pid: nil,
                user: nil,
                file: "/opt/homebrew/opt/grafana/homebrew.mxcl.grafana.plist",
                isRegistered: false,
                loadedFile: nil,
                command: "/opt/homebrew/opt/grafana/bin/grafana server",
                workingDirectory: "/opt/homebrew/var/lib/grafana",
                rootDirectory: nil,
                logPath: "/opt/homebrew/var/log/grafana-stdout.log",
                errorLogPath: "/opt/homebrew/var/log/grafana-stderr.log"
            )
        ])
    }

    func testFetchServicesFallsBackToListWhenInfoIsSparse() async throws {
        let provider = BrewServicesProvider(
            brewLocator: ServicesProviderTestBrewLocator(),
            runner: ServicesProviderTestCommandRunner(
                responses: [
                    """
                    [
                      {
                        "name": "postgresql@17",
                        "status": "started",
                        "user": "cmb",
                        "file": "/Users/cmb/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist",
                        "exit_code": null
                      }
                    ]
                    """,
                    """
                    [
                      {
                        "name": "postgresql@17"
                      }
                    ]
                    """
                ]
            )
        )

        let services = try await provider.fetchServices()

        XCTAssertEqual(services.count, 1)
        XCTAssertEqual(services[0].status, "started")
        XCTAssertEqual(services[0].user, "cmb")
        XCTAssertEqual(services[0].file, "/Users/cmb/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist")
        XCTAssertEqual(services[0].serviceName, "homebrew.mxcl.postgresql@17")
    }
}

private struct ServicesProviderTestBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

@MainActor
private final class ServicesProviderTestCommandRunner: CommandRunning, @unchecked Sendable {
    let responses: [String]
    private var callIndex = 0

    init(responses: [String]) {
        self.responses = responses
    }

    func run(
        executable: String,
        arguments: [String],
        onOutput: (@MainActor @Sendable (CommandOutputChunk) -> Void)?
    ) async throws -> CommandResult {
        defer { callIndex += 1 }
        let response = responses[min(callIndex, responses.count - 1)]
        return CommandResult(stdout: response, stderr: "", exitCode: 0)
    }
}
