import XCTest
@testable import Hodgepodge

@MainActor
final class CommandRunningTests: XCTestCase {
    func testProcessCommandRunnerCapturesSuccessfulOutput() async throws {
        let runner = ProcessCommandRunner()

        let result = try await runner.run(executable: "/bin/echo", arguments: ["hello"])

        XCTAssertEqual(result.stdout, "hello\n")
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

        let result = try await runner.run(
            executable: "/bin/sh",
            arguments: ["-c", "printf 'hello\\n'; printf 'warning\\n' >&2"],
            onOutput: { chunk in
                chunks.append(chunk)
            }
        )

        XCTAssertEqual(result.stdout, "hello\n")
        XCTAssertEqual(result.stderr, "warning\n")
        XCTAssertEqual(chunks.count, 2)
        XCTAssertTrue(chunks.contains(CommandOutputChunk(stream: .stdout, text: "hello\n")))
        XCTAssertTrue(chunks.contains(CommandOutputChunk(stream: .stderr, text: "warning\n")))
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
}
