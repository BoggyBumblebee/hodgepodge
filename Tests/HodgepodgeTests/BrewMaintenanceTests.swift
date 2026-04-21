import XCTest
@testable import Hodgepodge

final class BrewMaintenanceTests: XCTestCase {
    func testParserBuildsConfigSnapshot() {
        let snapshot = BrewMaintenanceParser.configSnapshot(from: """
        HOMEBREW_VERSION: 5.1.7
        HOMEBREW_PREFIX: /opt/homebrew
        macOS: 26.4.1-arm64
        Xcode: 26.4.1
        """)

        XCTAssertEqual(snapshot.version, "5.1.7")
        XCTAssertEqual(snapshot.prefix, "/opt/homebrew")
        XCTAssertEqual(snapshot.macOS, "26.4.1-arm64")
        XCTAssertEqual(snapshot.xcode, "26.4.1")
    }

    func testParserBuildsDoctorSnapshot() {
        let snapshot = BrewMaintenanceParser.doctorSnapshot(from: """
        Warning: The following directories are not writable by your user.
        Warning: Some installed casks are deprecated or disabled.
        """)

        XCTAssertEqual(snapshot.warningCount, 2)
        XCTAssertEqual(snapshot.warnings.first, "The following directories are not writable by your user.")
        XCTAssertEqual(snapshot.statusTitle, "2 warnings")
    }

    func testParserBuildsDryRunSnapshot() {
        let snapshot = BrewMaintenanceParser.dryRunSnapshot(task: .cleanup, from: """
        Warning: Skipping pydantic: most recent version 2.13.3 not installed
        Would remove: /tmp/example.tar.gz
        ==> This operation would free approximately 2.3KB of disk space.
        """)

        XCTAssertEqual(snapshot.task, .cleanup)
        XCTAssertEqual(snapshot.itemCount, 1)
        XCTAssertEqual(snapshot.spaceFreedEstimate, "2.3KB")
        XCTAssertEqual(snapshot.warnings, ["Skipping pydantic: most recent version 2.13.3 not installed"])
        XCTAssertEqual(snapshot.items, ["/tmp/example.tar.gz"])
    }

    func testSharedCommandExecutionStateTracksProgress() {
        let command = BrewMaintenanceActionCommand(task: .doctor, arguments: ["doctor"])
        let startedAt = Date(timeIntervalSince1970: 100)
        let finishedAt = Date(timeIntervalSince1970: 104)
        let progress = CommandExecutionProgress(command: command, startedAt: startedAt)
        let completed = progress.finished(at: finishedAt)

        XCTAssertEqual(progress.command, command)
        XCTAssertEqual(completed.elapsedTime(at: finishedAt), 4)
        XCTAssertEqual(CommandExecutionState.running(progress).command, command)
        XCTAssertEqual(CommandExecutionState.succeeded(completed, CommandResult(stdout: "", stderr: "", exitCode: 0)).progress, completed)
    }
}
