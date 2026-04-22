import XCTest
@testable import Hodgepodge

final class BrewTapTests: XCTestCase {
    func testStatusBadgesAndMetricsReflectTapMetadata() {
        let tap = BrewTap.fixture(
            isOfficial: true,
            customRemote: true,
            isPrivate: true,
            branch: "main"
        )

        XCTAssertEqual(tap.statusBadges, ["Official", "Custom Remote", "Private", "main"])
        XCTAssertEqual(tap.packageCount, 3)
        XCTAssertEqual(tap.summaryMetrics.map(\.value), ["2", "1", "0", "3"])
    }

    func testSubtitleFallsBackToPathWhenRemoteIsMissing() {
        let tap = BrewTap.fixture(remote: nil)

        XCTAssertEqual(tap.subtitle, tap.path)
    }

    func testActionCommandsReflectArgumentsAndConfirmation() {
        XCTAssertEqual(
            BrewTapActionCommand.add(name: "foo/bar", remoteURL: nil).arguments,
            ["tap", "foo/bar"]
        )
        XCTAssertEqual(
            BrewTapActionCommand.add(name: "foo/bar", remoteURL: "https://example.com/foo/homebrew-bar").arguments,
            ["tap", "foo/bar", "https://example.com/foo/homebrew-bar"]
        )
        XCTAssertEqual(
            BrewTapActionCommand.untap(name: "foo/bar", force: true).arguments,
            ["untap", "--force", "foo/bar"]
        )
        XCTAssertTrue(BrewTapActionKind.untap.requiresConfirmation)
    }
}
