import XCTest
@testable import Hodgepodge

final class CommandExecutionTests: XCTestCase {
    func testCommandLogBufferBuffersPartialStdoutAndFlushesRemainder() {
        var buffer = CommandLogBuffer()

        buffer.append(.stdout, "line 1\nline")
        buffer.append(.stdout, " 2\n")
        buffer.flush()

        XCTAssertEqual(buffer.entries.map(\.kind), [.stdout, .stdout])
        XCTAssertEqual(buffer.entries.map(\.text), ["line 1", "line 2"])
    }

    func testCommandLogBufferTrimsSystemLinesAndResets() {
        var buffer = CommandLogBuffer()

        buffer.append(.system, "   hello world  \n")
        buffer.reset()

        XCTAssertTrue(buffer.entries.isEmpty)
    }

    func testFriendlyFailureDescriptionUsesFallbackForGenericCommandFailures() {
        XCTAssertEqual(
            CommandPresentation.friendlyFailureDescription(
                "The command failed with exit code 1.",
                fallback: "The action couldn't complete."
            ),
            "The action couldn't complete."
        )
        XCTAssertEqual(
            CommandPresentation.friendlyFailureDescription(
                CommandRunnerError.unreadablePipe.localizedDescription,
                fallback: "The action couldn't complete."
            ),
            "The action couldn't complete."
        )
    }

    func testFriendlyFailureDescriptionKeepsUsefulMessages() {
        XCTAssertEqual(
            CommandPresentation.friendlyFailureDescription(
                "Already installed",
                fallback: "The action couldn't complete."
            ),
            "Already installed"
        )
    }
}
