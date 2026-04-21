import XCTest
@testable import Hodgepodge

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
}
