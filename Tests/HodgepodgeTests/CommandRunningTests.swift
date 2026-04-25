import XCTest
@testable import Hodgepodge

@MainActor
final class CommandRunningTests: XCTestCase {
    private let fileManager = FileManager.default

    func testProcessCommandRunnerCapturesSuccessfulOutput() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(
            executable: "/usr/bin/printf",
            arguments: ["hello"]
        )

        XCTAssertEqual(result.stdout, "hello")
        XCTAssertEqual(result.stderr, "")
        XCTAssertEqual(result.exitCode, 0)
    }

    func testProcessCommandRunnerThrowsForNonZeroExit() async {
        let runner = ProcessCommandRunner()

        do {
            _ = try await runner.run(executable: "/usr/bin/false", arguments: [])
            XCTFail("Expected a non-zero exit code to throw.")
        } catch let error as CommandRunnerError {
            guard case .nonZeroExitCode(let result) = error else {
                return XCTFail("Expected a non-zero exit code error.")
            }

            XCTAssertEqual(result.exitCode, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testProcessCommandRunnerStreamsStdoutAndStderr() async throws {
        let runner = ProcessCommandRunner()
        var chunks: [CommandOutputChunk] = []
        let receivedBothStreams = expectation(description: "Received stdout and stderr callbacks")

        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'hello\\n'; printf 'warning\\n' >&2"],
            onOutput: { chunk in
                chunks.append(chunk)
                let streams = Set(chunks.map(\.stream))
                if streams.contains(.stdout) && streams.contains(.stderr) {
                    receivedBothStreams.fulfill()
                }
            }
        )

        await fulfillment(of: [receivedBothStreams], timeout: 1.0)

        XCTAssertEqual(result.stdout, "hello\n")
        XCTAssertEqual(result.stderr, "warning\n")
        XCTAssertTrue(chunks.contains(where: { $0.stream == .stdout && $0.text.contains("hello") }))
        XCTAssertTrue(chunks.contains(where: { $0.stream == .stderr && $0.text.contains("warning") }))
    }

    func testProcessCommandRunnerCancelsLongRunningCommand() async {
        let runner = ProcessCommandRunner()
        let task = Task {
            try await runner.run(
                executable: "/bin/sh",
                arguments: ["-c", "sleep 10"],
                onOutput: nil
            )
        }

        await Task.yield()
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to throw.")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNonZeroExitCodeErrorDescriptionFallsBackToStdout() {
        let error = CommandRunnerError.nonZeroExitCode(
            CommandResult(
                stdout: "bundle check failed",
                stderr: "",
                exitCode: 1
            )
        )

        XCTAssertEqual(error.errorDescription, "bundle check failed")
    }

    func testCommandEnvironmentNormalizesPathForAbsoluteBrewExecutables() {
        let rootURL = fileManager.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let binURL = rootURL.appendingPathComponent("bin", isDirectory: true)
        let sbinURL = rootURL.appendingPathComponent("sbin", isDirectory: true)
        let brewURL = binURL.appendingPathComponent("brew")

        let environment = CommandEnvironment.normalized(
            for: brewURL.path,
            baseEnvironment: ["PATH": "/usr/bin:/bin"]
        )
        let pathEntries = environment["PATH"]?
            .split(separator: ":")
            .map(String.init) ?? []

        XCTAssertGreaterThanOrEqual(pathEntries.count, 2)
        XCTAssertEqual(pathEntries[0], binURL.path)
        XCTAssertEqual(pathEntries[1], sbinURL.path)
    }

    func testCommandEnvironmentNormalizesNamedBrewExecutables() {
        let environment = CommandEnvironment.normalized(
            for: "brew",
            baseEnvironment: ["PATH": "/usr/bin:/bin"]
        )

        XCTAssertEqual(
            environment["PATH"],
            "/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin"
        )
    }
}
