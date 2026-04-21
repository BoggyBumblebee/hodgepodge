import XCTest
@testable import Hodgepodge

final class BrewServiceTests: XCTestCase {
    func testStatusBadgesAndAvailableActionsReflectRunningState() {
        let running = BrewService.fixture()

        XCTAssertEqual(
            running.statusBadges,
            ["Started", "Running", "Loaded", "Registered"]
        )
        XCTAssertEqual(running.availableActions, [.restart, .stop])

        let stopped = BrewService.fixture(
            status: "none",
            isRunning: false,
            isLoaded: false,
            pid: nil,
            user: nil,
            isRegistered: false
        )

        XCTAssertEqual(stopped.statusBadges, ["Stopped"])
        XCTAssertEqual(stopped.availableActions, [.start])
    }

    func testFilterAndSortTitlesAreStable() {
        XCTAssertEqual(BrewServiceFilterOption.running.title, "Running")
        XCTAssertEqual(BrewServiceFilterOption.loaded.title, "Loaded")
        XCTAssertEqual(BrewServiceFilterOption.registered.title, "Registered")
        XCTAssertEqual(BrewServiceFilterOption.failed.title, "Needs Attention")
        XCTAssertEqual(BrewServiceSortOption.name.title, "Name")
        XCTAssertEqual(BrewServiceSortOption.status.title, "Status")
        XCTAssertEqual(BrewServiceSortOption.user.title, "User")
        XCTAssertEqual(BrewServiceSortOption.processID.title, "Process ID")
    }

    func testActionCommandBuildsExpectedArgumentsAndConfirmation() {
        let service = BrewService.fixture(name: "grafana", serviceName: "homebrew.mxcl.grafana")
        let command = service.command(for: .restart)

        XCTAssertEqual(command.arguments, ["services", "restart", "grafana"])
        XCTAssertEqual(command.command, "brew services restart grafana")
        XCTAssertEqual(command.confirmationTitle, "Restart grafana?")
        XCTAssertTrue(BrewServiceActionKind.restart.requiresConfirmation)
        XCTAssertFalse(BrewServiceActionKind.start.requiresConfirmation)
    }
}
